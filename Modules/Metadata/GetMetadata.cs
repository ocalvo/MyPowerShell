using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Management.Automation;

namespace CalvoSoftware
{
    [Cmdlet(VerbsCommon.Get, "Metadata")]
    public class GetMetadata: Cmdlet
    {
        [Parameter(Mandatory=true, ValueFromPipeline=true, Position=0)]
        [ValidateNotNullOrEmpty]
        public FileInfo Item
        {
            get;
            set;
        }

        protected override void ProcessRecord()
        {
            using (var fileStream = new FileStream(this.Item.FullName, FileMode.Open))
            using (var bitmap = new Bitmap(fileStream, useIcm:false))
            {
                if (bitmap.PropertyItems != null)
                {
                    var props = bitmap.PropertyItems
                        .Select(p => new Property(p));
                    base.WriteObject(props, enumerateCollection: true);
                }
            }
        }

        public abstract class PropertyTagType
        {
            public string Name { get; private set; }
            public int Count { get; private set; }

            public PropertyTagType(string name, int count)
            {
                this.Name = name;
                this.Count = count;
            }

            public abstract object GetValue(byte[] value, int count);
        }

        public class PropertyTagTypeASCII : PropertyTagType
        {
            public PropertyTagTypeASCII(string name)
                : base(name, 0)
            {
            }

            public override object GetValue(byte[] value, int count)
            {
                System.Text.ASCIIEncoding encoding = new System.Text.ASCIIEncoding();
                string text = encoding.GetString(value, 0, count - 1);
                return text;
            }
        }

        public class PropertyTagTypeDateTime : PropertyTagTypeASCII
        {
            public PropertyTagTypeDateTime(string name)
                : base(name)
            {
            }

            public override object GetValue(byte[] value, int count)
            {
                var text = base.GetValue(value, count);

                var provider = CultureInfo.InvariantCulture;
                var dateCreated = DateTime.ParseExact(text.ToString(), "yyyy:MM:d H:m:s", provider);
                return dateCreated;
            }
        }

        private static Dictionary<int, PropertyTagType> descriptors = new Dictionary<int, PropertyTagType>()
        {
            { 0x0132, new PropertyTagTypeDateTime("DateTaken") },
        };

        private class Property
        {
            private byte[] value;
            private int tag;
            private int count;
            private PropertyTagType descriptor;

            private PropertyTagType Descriptor
            {
                get
                {
                    if (this.descriptor == null)
                    {
                        descriptors.TryGetValue(this.tag, out this.descriptor);
                    }

                    return this.descriptor;
                }
            }

            public Property(PropertyItem propertyItem)
            {
                this.tag = propertyItem.Id;
                this.count = propertyItem.Len;
                this.value = propertyItem.Value;
            }

            public string Name
            {
                get
                {
                    if (this.Descriptor != null)
                    {
                        return this.Descriptor.Name;
                    }
                    else
                    {
                        return this.tag.ToString();
                    }
                }
            }

            public object Value
            {
                get
                {
                    if (this.Descriptor != null)
                    {
                        return this.Descriptor.GetValue(this.value, this.count);
                    }
                    else
                    {
                        return this.value;
                    }
                }
            }
        }
    }
}
