Change paths to match your environment.

```
brew install swift-protobuf
git clone https://github.com/teslamotors/vehicle-command
cd vehicle-command/pkg/protocol/protobuf
protoc --swift_out=. *.proto
cp *.swift moblin/Moblin/Integrations/Tesla/Protobuf
```
