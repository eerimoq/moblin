Change paths to match your environment.

```
brew install swift-protobuf
git clone https://github.com/gopro/OpenGoPro
cd OpenGoPro/protobuf
protoc --swift_out=. network_management.proto live_streaming.proto response_generic.proto
cp *.swift moblin/Moblin/Integrations/GoPro/Protobuf
```
