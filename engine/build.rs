fn main() -> Result<(), Box<dyn std::error::Error>> {
    let includes: &[&str] = &["../proto"];
    let protos: &[&str] = &["../proto/volvoxgrid.proto"];
    #[cfg(feature = "grpc")]
    {
        tonic_build::configure()
            .build_server(false)
            .build_client(false)
            .protoc_arg("--experimental_allow_proto3_optional")
            .compile(protos, includes)?;
    }
    #[cfg(not(feature = "grpc"))]
    {
        let mut config = prost_build::Config::new();
        config.protoc_arg("--experimental_allow_proto3_optional");
        config.compile_protos(protos, includes)?;
    }
    Ok(())
}
