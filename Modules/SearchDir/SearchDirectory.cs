using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Management.Automation;
using System.Text.RegularExpressions;

namespace DirHelper
{
    [Cmdlet(VerbsCommon.Search, "Directory")]
    public class SearchDirectory: Cmdlet
    {
        [Parameter(Mandatory=true)]
        [ValidateNotNullOrEmpty]
        public string[] SearchDirectories
        {
            get;
            set;
        }

        [Parameter(Mandatory=true)]
        public string[] ExcludeDirectories
        {
            get;
            set;
        }

        [Parameter(Mandatory = true)]
        [ValidateNotNullOrEmpty]
        public string Pattern
        {
            get;
            set;
        }

        [Parameter()]
        public SwitchParameter All
        {
            get;
            set;
        }

        [Parameter()]
        public bool SubstringMatch
        {
            get;
            set;
        }

        private List<Predicate<DirectoryInfo>> shouldInclude;
        private SearchQueue queue;

        private List<Predicate<DirectoryInfo>> CreateShouldIncludeList()
        {
            List<Predicate<DirectoryInfo>> result = new List<Predicate<DirectoryInfo>>();

            foreach (string excludeString in this.ExcludeDirectories)
            {
                if (Path.IsPathRooted(excludeString))
                {
                    string realPath = Path.GetFullPath(excludeString);
                    result.Add(dir => !StringComparer.OrdinalIgnoreCase.Equals(realPath, dir.FullName));
                }
                else
                {
                    string localExcludeString = excludeString; // Need this b/c of how lambdas work
                    result.Add(dir => !StringComparer.OrdinalIgnoreCase.Equals(localExcludeString, dir.Name));
                }
            }

            if (result.Count == 0)
            {
                result.Add(dir => true);
            }

            return result;
        }

        private bool ShouldInclude(DirectoryInfo directory)
        {
            return this.shouldInclude.All(f => f(directory));
        }

        protected override void BeginProcessing()
        {
            this.shouldInclude = CreateShouldIncludeList();

            PartQuery initialQuery = new PartQuery(this);
            this.queue = new SearchQueue();

            queue.AddRange(this.SearchDirectories.Select(searchDir => new SearchState(initialQuery, searchDir, 0)));

            base.BeginProcessing();
        }

        protected override void ProcessRecord()
        {
            if (this.SearchDirectories.Length == 0 || string.IsNullOrEmpty(this.Pattern))
            {
                return;
            }

            while (!queue.IsEmpty && !this.Stopping)
            {
                IEnumerable<SearchState> states = queue.DequeueNextSearchStateList();
                foreach (SearchState state in states)
                {
                    foreach (SearchState nextState in AdvanceSearch(state))
                    {
                        if (nextState.Query == null)
                        {
                            // We've got a winner..
                            this.WriteObject(nextState.Directory);
                            if (!this.All.IsPresent)
                            {
                                return;
                            }
                        }
                        else
                        {
                            queue.Add(nextState);
                        }

                        if (this.Stopping) { break; }
                    }

                    if (this.Stopping) { break; }
                }
            }
        }

        private IEnumerable<SearchState> AdvanceSearch(SearchState state)
        {
            var directories = Enumerable.Empty<DirectoryInfo>();
            try
            {
                directories = state.Directory.EnumerateDirectories();
            }
            catch (UnauthorizedAccessException)
            {
                directories = Enumerable.Empty<DirectoryInfo>();
            }

            foreach (var child in directories)
            {
                if (ShouldInclude(child))
                {
                    if (state.Query.Matches(child.Name))
                    {
                        // Assign higher strength to an exact match.
                        bool exact = StringComparer.OrdinalIgnoreCase.Equals(state.Query.QueryString, child.Name);

                        yield return new SearchState(state.Query.Next, child, exact ? 2 : 1);
                    }
                    else
                    {
                        yield return new SearchState(state.Query, child, 0);
                    }
                }
            }
        }

        sealed class SearchState
        {
            public SearchState(PartQuery query, string directory, int strength)
                : this(query, new DirectoryInfo(directory), strength)
            { }

            public SearchState(PartQuery query, DirectoryInfo directory, int strength)
            {
                this.Query = query;
                this.Directory = directory;
                this.Strength = strength;
            }

            public PartQuery Query
            {
                get;
                private set;
            }

            public DirectoryInfo Directory
            {
                get;
                private set;
            }

            public int Strength
            {
                get;
                private set;
            }

            public int Depth
            {
                get { return this.Query.Depth; }
            }

            public override string ToString()
            {
                return string.Format("Search State: {0}, {1} parts matched, strength = {2}", this.Directory.FullName, this.Depth, this.Strength);
            }
        }

        sealed class SearchQueue
        {
            private List<List<SearchState>> depthBuckets;
            private int count;

            public SearchQueue()
            {
                this.depthBuckets = new List<List<SearchState>>();
                this.count = 0;
            }

            public void Add(SearchState state)
            {
                GetBucket(state.Depth).Add(state);
                this.count++;
            }

            public void AddRange(IEnumerable<SearchState> states)
            {
                foreach (SearchState state in states)
                {
                    Add(state);
                }
            }

            public IEnumerable<SearchState> DequeueNextSearchStateList()
            {
                for (int i = this.depthBuckets.Count - 1; i >= 0; i--)
                {
                    if (this.depthBuckets[i].Count > 0)
                    {
                        List<SearchState> result = this.depthBuckets[i];
                        this.depthBuckets[i] = new List<SearchState>();
                        this.count -= result.Count;

                        result.Sort((x, y) => y.Strength.CompareTo(x.Strength));

                        return result;
                    }
                }

                return null;
            }

            public bool IsEmpty
            {
                get { return this.count == 0; }
            }

            private List<SearchState> GetBucket(int depth)
            {
                while (this.depthBuckets.Count <= depth)
                {
                    this.depthBuckets.Add(new List<SearchState>());
                }

                return this.depthBuckets[depth];
            }
        }

        sealed class PartQuery
        {
            public PartQuery(SearchDirectory options)
                : this(options, options.Pattern.Split('\\'), 0)
            { }

            private PartQuery(SearchDirectory options, IEnumerable<string> parts, int depth)
            {
                string matchString = parts.First();
                this.QueryString = matchString;
                this.Matches = CreateMatcher(options, matchString);

                if (parts.Count() > 1)
                {
                    this.Next = new PartQuery(options, parts.Skip(1), depth + 1);
                }

                this.Depth = depth;
            }

            private static Predicate<string> CreateMatcher(SearchDirectory options, string matchString)
            {
                const string tmpString = "__SHAZAM,,";
                if (options.SubstringMatch)
                {
                    if (matchString.Contains('*'))
                    {
                        Regex re = new Regex("^.*" + Regex.Escape(matchString.Replace("*", tmpString)).Replace(tmpString, ".*") + ".*$", RegexOptions.IgnoreCase);
                        return s => re.IsMatch(s);
                    }
                    else
                    {
                        return s => -1 != s.IndexOf(matchString, StringComparison.OrdinalIgnoreCase);
                    }
                }
                else
                {
                    if (matchString.Contains('*'))
                    {
                        Regex re = new Regex("^" + Regex.Escape(matchString.Replace("*", tmpString)).Replace(tmpString, ".*") + ".*$", RegexOptions.IgnoreCase);
                        return s => re.IsMatch(s);
                    }
                    else
                    {
                        return s => s.StartsWith(matchString, StringComparison.OrdinalIgnoreCase);
                    }
                }
            }

            public Predicate<string> Matches
            {
                get;
                private set;
            }

            public string QueryString
            {
                get;
                private set;
            }

            public PartQuery Next
            {
                get;
                private set;
            }

            public int Depth
            {
                get;
                private set;
            }
        }
    }
}
