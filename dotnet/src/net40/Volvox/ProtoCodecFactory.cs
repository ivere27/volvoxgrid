namespace VolvoxGrid.DotNet.Internal
{
    internal static class ProtoCodecFactory
    {
        public static IProtoCodec Create()
        {
            return new ProtoLiteCodec();
        }
    }
}
