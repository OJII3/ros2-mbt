# ros2-mbt

MoonBitでROS 2ネットワークと相互運用するための、DDS/RTPSサブセット実装です。
ROS 2そのものをリンクせず、まずはnative backend上でRTPS wire formatを扱うことを目標にしています。

## 現在の実装

- RTPS message header (`RTPS` magic、protocol version、vendor ID、GUID prefix)
- RTPS submessage header（ID、flags、payload length、little-endian flag）
- RTPS `EntityId` / `Guid` の16バイトwire format
- RTPS `Locator_t` と UDP/IPv4 locator のwire format
- RTPS parameter list（SPDP/SEDP向けのPID、4バイト境界、sentinel）
- RTPS `DATA` submessage（CDR payload、inline QoS、SequenceNumber）
- RTPS message container（header + 複数 submessage の serialize/parse）
- SPDP participant data の ParameterList生成・解析とDATA message/UDP helper
- SEDP endpoint data（topic/type、locator、任意QoS）の生成・解析とUDP helper
- ROS 2で使うCDR little-endian encapsulation (`00 01 00 00`)
- CDRのprimitive、UTF-8 string、byte sequenceのエンコード/デコード
- native async UDPのbind、unicast送受信、multicast socket wrapper
- `std_msgs/msg/String` と `geometry_msgs/msg/Twist` の最小CDR codec
- 不正な長さ、truncated payload、不正なencapsulationの検証

## 開発

Nix devShellを使う場合:

```sh
nix develop
moon fmt
moon check
moon test --target native
```

SPDP/SEDPのmulticast discovery loop、ROS message codegen、Cyclone DDS/Fast DDSとの実通信試験は未実装です。

## Roadmap

1. UDP multicast/unicast transport
2. SPDP participant discovery
3. SEDP endpoint discovery
4. `DATA` submessageとROS topic mapping
5. `geometry_msgs/Twist`などの最小ROS message codegen
6. Cyclone DDS / Fast DDSとのtalker-listener相互運用テスト
