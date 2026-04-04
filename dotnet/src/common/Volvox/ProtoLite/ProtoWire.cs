using System;
using System.IO;
using System.Text;

namespace VolvoxGrid.DotNet.Internal.ProtoLite
{
    internal enum ProtoWireType
    {
        Varint = 0,
        Fixed64 = 1,
        LengthDelimited = 2,
        Fixed32 = 5,
    }

    internal sealed class ProtoWriter
    {
        private readonly MemoryStream _stream;

        public ProtoWriter()
        {
            _stream = new MemoryStream();
        }

        public byte[] ToArray()
        {
            return _stream.ToArray();
        }

        public void WriteTag(int fieldNumber, ProtoWireType wireType)
        {
            var tag = ((ulong)fieldNumber << 3) | (ulong)wireType;
            WriteVarintRaw(tag);
        }

        public void WriteInt32(int fieldNumber, int value)
        {
            WriteTag(fieldNumber, ProtoWireType.Varint);
            WriteVarintRaw(unchecked((ulong)(long)value));
        }

        public void WriteInt64(int fieldNumber, long value)
        {
            WriteTag(fieldNumber, ProtoWireType.Varint);
            WriteVarintRaw(unchecked((ulong)value));
        }

        public void WriteBool(int fieldNumber, bool value)
        {
            WriteTag(fieldNumber, ProtoWireType.Varint);
            WriteVarintRaw(value ? 1UL : 0UL);
        }

        public void WriteFloat(int fieldNumber, float value)
        {
            WriteTag(fieldNumber, ProtoWireType.Fixed32);
            var bytes = BitConverter.GetBytes(value);
            _stream.Write(bytes, 0, 4);
        }

        public void WriteDouble(int fieldNumber, double value)
        {
            WriteTag(fieldNumber, ProtoWireType.Fixed64);
            var bytes = BitConverter.GetBytes(value);
            _stream.Write(bytes, 0, 8);
        }

        public void WriteString(int fieldNumber, string value)
        {
            if (value == null)
            {
                value = string.Empty;
            }

            var bytes = Encoding.UTF8.GetBytes(value);
            WriteBytes(fieldNumber, bytes);
        }

        public void WriteBytes(int fieldNumber, byte[] value)
        {
            if (value == null)
            {
                value = new byte[0];
            }

            WriteTag(fieldNumber, ProtoWireType.LengthDelimited);
            WriteVarintRaw((ulong)value.Length);
            _stream.Write(value, 0, value.Length);
        }

        public void WriteMessage(int fieldNumber, Action<ProtoWriter> messageWriter)
        {
            var nested = new ProtoWriter();
            messageWriter(nested);
            WriteBytes(fieldNumber, nested.ToArray());
        }

        public void WriteMessageBytes(int fieldNumber, byte[] messageBytes)
        {
            WriteBytes(fieldNumber, messageBytes);
        }

        private void WriteVarintRaw(ulong value)
        {
            while (value >= 0x80)
            {
                _stream.WriteByte((byte)(value | 0x80));
                value >>= 7;
            }

            _stream.WriteByte((byte)value);
        }
    }

    internal sealed class ProtoReader
    {
        private readonly byte[] _buffer;
        private int _position;

        public ProtoReader(byte[] buffer)
        {
            _buffer = buffer ?? new byte[0];
            _position = 0;
        }

        public bool IsEof
        {
            get { return _position >= _buffer.Length; }
        }

        public bool TryReadTag(out int fieldNumber, out ProtoWireType wireType)
        {
            if (IsEof)
            {
                fieldNumber = 0;
                wireType = 0;
                return false;
            }

            var tag = ReadVarintRaw();
            fieldNumber = (int)(tag >> 3);
            wireType = (ProtoWireType)(tag & 0x07);
            return true;
        }

        public int ReadInt32()
        {
            return unchecked((int)ReadVarintRaw());
        }

        public long ReadInt64()
        {
            return unchecked((long)ReadVarintRaw());
        }

        public bool ReadBool()
        {
            return ReadVarintRaw() != 0;
        }

        public float ReadFloat()
        {
            EnsureAvailable(4);
            var value = BitConverter.ToSingle(_buffer, _position);
            _position += 4;
            return value;
        }

        public double ReadDouble()
        {
            EnsureAvailable(8);
            var value = BitConverter.ToDouble(_buffer, _position);
            _position += 8;
            return value;
        }

        public byte[] ReadLengthDelimited()
        {
            var len = (int)ReadVarintRaw();
            EnsureAvailable(len);
            var bytes = new byte[len];
            Buffer.BlockCopy(_buffer, _position, bytes, 0, len);
            _position += len;
            return bytes;
        }

        public string ReadString()
        {
            var bytes = ReadLengthDelimited();
            return Encoding.UTF8.GetString(bytes, 0, bytes.Length);
        }

        public void SkipField(ProtoWireType wireType)
        {
            switch (wireType)
            {
                case ProtoWireType.Varint:
                    ReadVarintRaw();
                    break;

                case ProtoWireType.Fixed64:
                    EnsureAvailable(8);
                    _position += 8;
                    break;

                case ProtoWireType.LengthDelimited:
                    var len = (int)ReadVarintRaw();
                    EnsureAvailable(len);
                    _position += len;
                    break;

                case ProtoWireType.Fixed32:
                    EnsureAvailable(4);
                    _position += 4;
                    break;

                default:
                    throw new InvalidDataException("Unsupported protobuf wire type: " + (int)wireType);
            }
        }

        private ulong ReadVarintRaw()
        {
            ulong result = 0;
            int shift = 0;

            while (true)
            {
                EnsureAvailable(1);
                byte b = _buffer[_position++];
                result |= ((ulong)(b & 0x7F)) << shift;

                if ((b & 0x80) == 0)
                {
                    return result;
                }

                shift += 7;
                if (shift > 63)
                {
                    throw new InvalidDataException("Malformed protobuf varint.");
                }
            }
        }

        private void EnsureAvailable(int count)
        {
            if (_position + count > _buffer.Length)
            {
                throw new EndOfStreamException("Unexpected end of protobuf payload.");
            }
        }
    }
}
