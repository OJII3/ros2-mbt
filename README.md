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
- UDP datagram内のSPDP/SEDP discovery event dispatch（publication/subscription判定を含む）
- SPDP announcement の sequence number 管理と async periodic session helper
- 発見済み participant の metatraffic locator へ送る SEDP helper
- DDSI-RTPS default port mapping、SPDP/user-data address helper
- DDSI discoveryのSPDP multicastとmetatraffic unicast両受信
- DDSI 標準 locator と builtin endpoint を設定する participant helper
- discovery/user-data socket をまとめる `RosParticipant` lifecycle facade
- `RosParticipant` のローカルSEDP endpoint登録・保持・発見時自動再通知
- topic・entity ID・QoSからuser locator付きSEDP endpointを登録するparticipant API
- 登録済みendpointから`ParticipantEntitiesInfo`を生成するROS graph metadata API
- reliable `ros_discovery_info` endpointをparticipantへ登録するAPI
- 発見したgraph endpointに対応するreliable reader/writerの自動生成とgraph metadata送受信
- user DATA submessage の RTPS message/UDP helper
- best-effort `DataWriter`（sequence number 管理付き）
- 発見済み SEDP endpoint から作る best-effort `DataReader` / `DataWriter`
- `RosTopic` と発見済み endpoint を結ぶ `RosPublisher` / `RosSubscription` facade
- reliable QoS向けの `ReliableRosPublisher` / `ReliableRosSubscription` facade
- `ros_discovery_info` 向けの reliable graph publisher/subscription facade
- `RosTopic` と `std_msgs/msg/String` を使った loopback publisher/listener test
- RTPS HEARTBEAT / ACKNACK の codec と UDP helper
- reliable writer の送信履歴、HEARTBEAT、ACKNACK 指定再送
- reliable SEDP writer と UDP-backed reliable reader session
- reliable reader の受信 sequence 管理と ACKNACK bitmap 生成
- SPDP/SEDP discovery event を保持する `DiscoveryGraph` と topic/type matching
- SPDP/SEDP と `ros_discovery_info` を graph に集約する `DiscoveryService`
- 発見済み participant 全体への SEDP endpoint の単発・有限回・継続 announcement
- `rmw_dds_common` の `Gid` / `NodeEntitiesInfo` / `ParticipantEntitiesInfo` CDR codec
- `ros_discovery_info` の DDS identity と graph discovery QoS descriptor
- ROS topic descriptor から QoS付きSEDP topic/type identity への bridge
- ROS 2で使うCDR little-endian encapsulation (`00 01 00 00`)
- CDRのprimitive、UTF-8 string、byte sequenceのエンコード/デコード
- native async UDPのbind、unicast送受信、multicast socket wrapper
- `std_msgs/msg/String` と `geometry_msgs/msg/Twist` の最小CDR codec
- primitive / scalar constant / nested message `.msg` の parser / MoonBit CDR codec generator（固定配列・bounded/unbounded sequence 対応、明示的な型参照に対応、`rosidl`）
- 複数 `.msg` source の依存順解決と外部ROS package向けMoonBit import生成
- 不正な長さ、truncated payload、不正なencapsulationの検証

## 開発

Nix devShellを使う場合:

```sh
nix develop
moon fmt
moon check
moon test --target native
```

Cyclone DDS/Fast DDSとの実通信試験は未実装です。

## Roadmap

1. UDP multicast/unicast transport（基本送受信、SPDP multicast helper、単発 discovery packet は実装済み）
2. SPDP participant discovery（packet codec、受信 dispatch、周期 announcement は実装済み）
3. SEDP endpoint discovery（packet codec、受信 dispatch、participant locator への単発・周期送信は実装済み）
4. `DATA` submessage と ROS topic mapping（best-effort reader/writer adapter まで実装済み）
5. `geometry_msgs/Twist`などのROS message codec（primitive・scalar constants・固定配列・bounded/sequence・nested type codegen・複数ファイル依存解決は実装済み）
6. Cyclone DDS / Fast DDSとのtalker-listener相互運用テスト
