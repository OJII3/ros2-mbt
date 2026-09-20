# ros2-mbt

MoonBitでROS 2ネットワークと相互運用するための、DDS/RTPSサブセット実装です。
ROS 2そのものをリンクせず、まずはnative backend上でRTPS wire formatを扱うことを目標にしています。

## 現在の実装

- RTPS message header (`RTPS` magic、protocol version、vendor ID、GUID prefix)
- RTPS submessage header（ID、flags、payload length、little-endian flag）
- RTPS `PAD`、未知/ベンダーsubmessageの透過的な解析
- RTPS submessageの4バイト境界配置と末尾submessageのzero-length解析
- RTPS `EntityId` / `Guid` の16バイトwire format
- RTPS `INFO_DST` submessage（宛先GUID prefix）のcodec、送信時付与、受信時宛先判定
- RTPS `Locator_t` と UDP/IPv4 locator のwire format
- RTPS parameter list（SPDP/SEDP向けのPID、4バイト境界、sentinel）
- RTPS `DATA` submessage（CDR payload、inline QoS、SequenceNumber）
- RTPS `DATA` key-only payloadと`PID_STATUS_INFO`（dispose/unregister）
- RTPS `DATA_FRAG` の fragment codec と best-effort/reliable reader の再構成
- RTPS `GAP`、`HEARTBEAT_FRAG`、`NACK_FRAG` の codec と reliable fragment再送要求
- RTPS `INFO_TS` submessage（NTP timestamp、Invalidate flag、両エンディアン）
- 対応済みRTPS submessageのE flagに応じたbig/little-endian受信（送信はlittle-endian）
- SPDP/SEDP ParameterListの`PL_CDR_BE` / `PL_CDR_LE`受信（生成はlittle-endian）
- RTPS message container（header + 複数 submessage の serialize/parse）
- SPDP participant data の ParameterList生成・解析とDATA message/UDP helper
- SEDP endpoint data（topic/type、locator、任意QoS）の生成・解析とUDP helper
- SEDPのreliability/durability/deadline/liveliness/lease/data representation解析とendpoint互換性判定
- SEDP endpoint GUIDに対応する`PID_KEY_HASH`の広告・解析
- SEDP publication/subscription向け標準パラメータ（型サイズ、inline QoS期待値）の広告
- SPDP/SEDP DATA_FRAG の受信再構成、reliable SEDPのHEARTBEAT_FRAGへのNACK_FRAG応答と HEARTBEAT への ACKNACK 応答
- SEDP ACKNACK に対する送信済み discovery DATA の再送
- `DiscoverySession`による、1 RTPS datagram内の複数SPDP/SEDP DATA eventの順次dispatch（publication/subscription判定を含む）
- SPDP announcement の sequence number 管理と async periodic session helper
- SPDP participant dispose DATAの生成・送信API
- SEDP endpoint dispose DATAの送信とACKNACK再送履歴
- 発見済み participant の metatraffic locator へ送る SEDP helper
- SEDP DATA後のHEARTBEAT送信と共有metatraffic socketの非discovery datagram処理
- DDSI-RTPS default port mapping、SPDP/user-data address helper
- DDSI discoveryのSPDP multicastとmetatraffic unicast両受信
- DDSI 標準 locator と builtin endpoint を設定する participant helper
- discovery/user-data socket をまとめる `RosParticipant` lifecycle facade
- `RosParticipant` のローカルSEDP endpoint登録・保持・発見時自動再通知
- topic・entity ID・QoSからuser locator付きSEDP endpointを登録するparticipant API
- topic SEDPの`PID_USER_DATA`へのROS RIHS01型ハッシュ広告と、型ハッシュ付きtopic登録API
- 登録済みendpointから`ParticipantEntitiesInfo`を生成するROS graph metadata API
- node namespace/nameを設定したparticipantによる`ros_discovery_info`の自動更新・再送
- reliable `ros_discovery_info` endpointをparticipantへ登録するAPI
- 発見したgraph endpointに対応するreliable reader/writerの自動生成とgraph metadata送受信
- user DATA submessage の RTPS message/UDP helper
- best-effort `DataWriter`（sequence number 管理付き）
- best-effort writer の大きい payload の DATA_FRAG 送信
- 発見済み SEDP endpoint から作る best-effort `DataReader` / `DataWriter`
- `RosTopic` と発見済み endpoint を結ぶ `RosPublisher` / `RosSubscription` facade
- reliable QoS向けの `ReliableRosPublisher` / `ReliableRosSubscription` facade
- ROS service の request/response DDS topic・type identity descriptor
- ROS service request/response endpointのRIHS01型ハッシュ広告API
- DDS-RPC enhanced service discovery向けの request/response 関連 endpoint GUID
- RTPS DDS-RPC related sample identity と inline QoS
- reliable ROS service client/server facade（request/reply 相関付き）
- `ros_discovery_info` 向けの reliable graph publisher/subscription facade
- `RosTopic` と `std_msgs/msg/String` を使った loopback publisher/listener test
- RTPS HEARTBEAT / ACKNACK の codec と UDP helper
- reliable writer の送信履歴、ACKNACK累積確認による履歴解放、HEARTBEAT、ACKNACK指定再送
- reliable writer の大きい payload の DATA_FRAG送信、HEARTBEAT_FRAG、NACK_FRAG再送
- reliable SEDP writer と UDP-backed reliable reader session
- reliable reader の受信 sequence 管理と ACKNACK bitmap 生成
- GAPを反映したACKNACK生成と、fragment欠落を反映したNACK_FRAG生成
- SPDP/SEDP discovery event を保持する `DiscoveryGraph` と topic/type matching
- SPDP/SEDP key-only dispose/unregister による参加者・endpoint削除
- SPDP/SEDP と `ros_discovery_info` を graph に集約する `DiscoveryService`
- 発見済み participant 全体への SEDP endpoint の単発・有限回・継続 announcement
- `rmw_dds_common` の `Gid` / `NodeEntitiesInfo` / `ParticipantEntitiesInfo` CDR codec
- `ros_discovery_info` の DDS identity と graph discovery QoS descriptor
- ROS topic descriptor から QoS付きSEDP topic/type identity への bridge
- ROS 2 CDR_BE / CDR_LE encapsulationの読み取りと、CDR_LE (`00 01 00 00`) の生成
- CDRのprimitive、UTF-8 string、byte sequenceのエンコード/デコード
- native async UDPのbind、unicast送受信、multicast socket wrapper
- `std_msgs/msg/String` と `geometry_msgs/msg/Twist` の最小CDR codec
- primitive / scalar constant / nested message `.msg` の parser / MoonBit CDR codec generator（固定配列・bounded/unbounded sequence・bounded string 対応、明示的な型参照に対応、`rosidl`）
- `.msg` のRIHS01型ハッシュ計算と生成コードへの`*_TYPE_HASH`定数埋め込み（bounded string capacity・primitive・同一workspace内のnested type）
- `.srv` の request/response 分割 parser と MoonBit CDR codec generator
- `.srv` のRIHS01 service型ハッシュ計算（primitiveは直接、nestedはworkspace経由）
- primitive request/response `.srv` の生成コードへの`<Service>_TYPE_HASH`定数埋め込み
- 複数 `.msg` source の依存順解決と外部ROS package向けMoonBit import生成
- `std_msgs/msg/String` を外部ROS 2と送受信する実行可能な `examples/talker` / `examples/listener`
- `example_interfaces/srv/AddTwoInts` を外部ROS 2と呼び出す実行可能な `examples/service_server` / `examples/service_client`
- 不正な長さ、truncated payload、不正なencapsulationの検証

## 開発

Nix devShellを使う場合:

```sh
nix develop
moon fmt
moon check
moon test --target native
```

外部ROS 2との最小通信を試す場合は、別の端末で購読者を起動してから talker を実行します。

```sh
# 別ホストで実行する場合は、ROS 2から到達できるMoonBit側のIPv4アドレスを指定する
export ROS2_MBT_IP=192.168.1.20
export ROS_DOMAIN_ID=0
ros2 topic echo /chatter std_msgs/msg/String
direnv exec . moon run examples/talker
```

逆方向は、ROS 2側でpublisherを起動してからlistenerを実行します。

```sh
ros2 topic pub --qos-reliability reliable /chatter std_msgs/msg/String "{data: hello from ROS 2}"
direnv exec . moon run examples/listener
```

`examples/talker` はSPDP/SEDPで `/chatter` の購読者を発見した後、相手のreliability QoSに合わせて `std_msgs/msg/String` を5件送信します。`examples/listener` もpublicationのQoSに応じたreaderを選択し、5件受信してCDRを復号します。両exampleともnode identityを設定し、endpoint登録・発見時の`ros_discovery_info`を自動更新します。`ROS2_MBT_IP` はMoonBit participantがDDSI locatorとして広告するローカルIPv4アドレスで、未設定時は `127.0.0.1` です。`ROS_DOMAIN_ID` はROS 2側と一致させ、未設定時は `0` です。ROS 2側のDDS実装と到達可能なネットワークで実行してください。macOSでは、依存しているUDP multicast socketの同一ポート共有がOSの負荷分散対象になるため、同一ホスト上で複数participantを動かす検証は不安定です。Cyclone DDS 11.0.1およびFast DDS 3.6.2とのtalker-listener双方向実通信は、固定unicast locatorを使った検証で確認済みです。Fast DDSではString sampleを双方向それぞれ5件受信しました。ROS 2 CLIとの実通信は未実施です。

serviceの動作確認は、MoonBit serverに対してROS 2 CLIまたはDDS clientから呼び出すか、ROS 2 serverを起動してMoonBit clientから呼び出します。

```sh
ROS2_MBT_IP=192.168.1.20 ROS_DOMAIN_ID=0 direnv exec . moon run examples/service_server
ros2 service call /add_two_ints example_interfaces/srv/AddTwoInts "{a: 2, b: 3}"

ros2 run demo_nodes_cpp add_two_ints_server
ROS2_MBT_IP=192.168.1.20 ROS_DOMAIN_ID=0 direnv exec . moon run examples/service_client
```

service例は `AddTwoInts` のrequest/responseをCDRで符号化し、DDS-RPCのrelated sample identityで相関させます。
Cyclone DDS 11.0.1では、`rmw_cyclonedds_cpp`互換のpayload header（`uint64 client_id` + `int64 sequence`）を使うrequest/replyを、固定unicast discoveryでMoonBit server/clientの双方向について確認済みです。Fast DDS 3.6.2とも、inline `RELATED_SAMPLE_IDENTITY`を使う`AddTwoInts` request/replyをMoonBit client/serverの双方向で確認しました。ROS graph用の`ros_discovery_info`はCyclone DDS readerおよびFast DDS 3.6.2 raw DDS readerへのsample送信を確認済みです。ROS 2 CLIとの実通信、およびROS graph全体の相互運用は未確認です。

## Roadmap

1. UDP multicast/unicast transport（基本送受信、SPDP multicast helper、単発 discovery packet は実装済み）
2. SPDP participant discovery（packet codec、DATA/DATA_FRAG受信 dispatch、周期 announcement は実装済み）
3. SEDP endpoint discovery（packet codec、受信 dispatch、participant locator への単発・周期送信は実装済み）
4. `DATA` / `DATA_FRAG` submessage と ROS topic mapping（best-effort/reliable reader adapter まで実装済み）
5. `geometry_msgs/Twist`などのROS message codec（primitive・scalar constants・固定配列・bounded/sequence・nested type codegen・複数ファイル依存解決は実装済み）
6. ROS service の request/reply facade と `.srv` codec（実装済み、loopback test 済み、Cyclone DDS 11.0.1のinline形式および`rmw_cyclonedds_cpp`互換payload形式を双方向検証済み）
7. Cyclone DDS / Fast DDSとのtopic・service・graph相互運用テスト（Cyclone DDS 11.0.1のtopic/service双方向と`ros_discovery_info`受信、Fast DDS 3.6.2のtopic/service双方向とraw DDS readerへのgraph sample送信を確認済み。ROS 2 CLIとgraph全体は未確認）
