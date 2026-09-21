# ros2-mbt

MoonBitでROS 2ネットワークと相互運用するための、DDS/RTPSサブセット実装です。
ROS 2そのものをリンクせず、まずはnative backend上でRTPS wire formatを扱うことを目標にしています。

## 現在の実装

- RTPS wire format と CDR の codec。DATA/DATA_FRAG、reliability submessage、GUID/locator、endianness、malformed packet の検証に対応。
- SPDP/SEDP discovery と participant lifecycle。multicast/unicast、QoS matching、再送、dispose を扱い、`DiscoveryGraph` と `ros_discovery_info` に ROS graph 情報を集約。
- best-effort/reliable な ROS topic の送受信。発見済み endpoint との接続、fragmentation、QoS に応じた publisher/subscriber を提供。
- DDS-RPC service、ROS Action client、parameter client。request/reply 相関、Action endpoint discovery、goal feedback/status に対応。
- `.msg` / `.srv` / `.action` parser と MoonBit CDR codec generator。RIHS01 hash、nested type/import、配列・sequence・string/wstring、定数・default 値に対応。
- String/WString topic、AddTwoInts service、Fibonacci Action、parameter の実行例。Cyclone DDS、Fast DDS、ROS 2 Jazzy CLI との相互運用テストあり。

## 開発

Nix devShellを使う場合:

```sh
nix develop
moon fmt
moon check
moon test --target native
```

ROS 2 Jazzy CLIとの相互運用テストを行う場合は、専用devShellに入ります。
ROS 2は相互運用テスト専用です。MoonBitの各packageと標準の`nix develop` shellにはROS 2 packageを含めません。
`ros-core`、`demo-nodes-cpp`、`example-interfaces`、`action-tutorials-interfaces` が利用可能です。`ros-core`から`rclpy`と`rcl_interfaces`も使えます。
WString codecはNix devShellのROS 2 Jazzy/Fast DDSで実測したFast-CDR互換表現（UTF-16 code unitを32-bit wcharとして符号化）を使います。DDS-XTypesの標準wide-string表現とは異なる実装があるため、他DDSとの相互運用は別途確認が必要です。

```sh
nix develop .#ros2
bash scripts/ros2_cli_interop.sh
bash scripts/ros2_action_interop.sh
bash scripts/ros2_parameter_interop.sh
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

`examples/talker` はSPDP/SEDPで `/chatter` の購読者を発見した後、相手のreliability QoSに合わせて `std_msgs/msg/String` を5件送信します。`examples/listener` もpublicationのQoSに応じたreaderを選択し、5件受信してCDRを復号します。WString用exampleも同じQoS選択で `/wide_chatter` を送受信します。両example群ともnode identityを設定し、endpoint登録・発見時の`ros_discovery_info`を自動更新します。`ROS2_MBT_IP` はMoonBit participantがDDSI locatorとして広告するローカルIPv4アドレスで、未設定時は `127.0.0.1` です。`ROS2_MBT_MULTICAST_IP` はSPDP multicastの送受信interfaceを固定する任意設定で、未設定時はOSに選択を任せます。`ROS_DOMAIN_ID` はROS 2側と一致させ、未設定時は `0` です。ROS 2側のDDS実装と到達可能なネットワークで実行してください。macOSでは、依存しているUDP multicast socketの同一ポート共有がOSの負荷分散対象になるため、同一ホスト上で複数participantを動かす検証は不安定です。Cyclone DDS 11.0.1およびFast DDS 3.6.2とのtalker-listener双方向実通信は、固定unicast locatorを使った検証で確認済みです。Fast DDSではString sampleを双方向それぞれ5件受信しました。Nix devShellのROS 2 Jazzy CLIとのString/WString topicおよびservice双方向通信もmacOSで確認済みです。Linux CIでは`ros2 node list` / `ros2 node info`に加え、`ros_discovery_info`内のnode namespace/nameと`/chatter` publisher GIDの一致も検証します。macOSではmulticastの同一ポート共有が不安定なため、graph assertionは省略します。

serviceの動作確認は、MoonBit serverに対してROS 2 CLIまたはDDS clientから呼び出すか、ROS 2 serverを起動してMoonBit clientから呼び出します。

```sh
ROS2_MBT_IP=192.168.1.20 ROS_DOMAIN_ID=0 direnv exec . moon run examples/service_server
ros2 service call /add_two_ints example_interfaces/srv/AddTwoInts "{a: 2, b: 3}"

ros2 run demo_nodes_cpp add_two_ints_server
ROS2_MBT_IP=192.168.1.20 ROS_DOMAIN_ID=0 direnv exec . moon run examples/service_client
```

Action相互運用テストはNix devShellのROS 2 Jazzy `rclpy` ActionServerを起動し、`example_interfaces`と`action_tutorials_interfaces`のFibonacci Actionそれぞれで、MoonBit clientの通常完了（goal受付、Feedback、Succeeded result/status topic）とCancelGoal（受理コード、Canceled result/status topic）を検証します。

```sh
nix develop .#ros2 --command bash scripts/ros2_action_interop.sh
```

Parameter相互運用テストは`rclpy` nodeの標準parameter serviceを使い、MoonBitから`SetParameters`と`SetParametersAtomically`で整数parameterを更新し、`GetParameterTypes`で型、`GetParameters`で値を取得し、`ListParameters`で列挙、`DescribeParameters`でdescriptorを取得します。

```sh
nix develop .#ros2 --command bash scripts/ros2_parameter_interop.sh
```

PodmanでLinux上の検証一式を実行する場合は、次を使います。macOSでは事前にPodman machineを初期化・起動してください。ROS 2とMoonBitの両方を同じコンテナ内で実行するため、macOSホストとPodman VMの間でDDS multicastを通す必要はありません。ソースは読み取り専用でマウントし、コンテナ内の一時領域にコピーしてテストします。

```sh
# macOS: 初回のみ
podman machine init
# macOS: machineが停止しているとき
podman machine start
# Linuxではmachineの起動は不要
bash scripts/ros2_podman_interop.sh
```

このスクリプトはROS 2 Jazzy `ros-base` imageにテスト用interface/demo packageとMoonBit toolchainを加え、format、check、native test、topic/service、Action、Parameter相互運用を順に実行します。

service例は `AddTwoInts` のrequest/responseをCDRで符号化し、DDS-RPCのrelated sample identityで相関させます。
Cyclone DDS 11.0.1では、`rmw_cyclonedds_cpp`互換のpayload header（`uint64 client_id` + `int64 sequence`）を使うrequest/replyを、固定unicast discoveryでMoonBit server/clientの双方向について確認済みです。Fast DDS 3.6.2とも、inline `RELATED_SAMPLE_IDENTITY`を使う`AddTwoInts` request/replyをMoonBit client/serverの双方向で確認しました。ROS graph用の`ros_discovery_info`はCyclone DDS readerおよびFast DDS 3.6.2 raw DDS readerへのsample送信を確認済みです。Nix devShellのROS 2 Jazzy CLIとのString/WString topicおよびservice双方向通信もmacOSで確認済みですが、網羅的なROS graph相互運用は未確認です。

## Roadmap

- ROS graph 相互運用の拡充。Linux CI で MoonBit node と `/chatter` publisher の namespace/name/GID、および AddTwoInts service node/endpoint の発見を確認済み。多様な node/endpoint 構成を含む網羅的な graph 整合性は未確認。
