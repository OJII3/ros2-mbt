///|
/// Test receive operations must fail instead of waiting forever.
const TEST_RECEIVE_TIMEOUT_MS : Int = 5_000

///|
async fn[T] test_receive(receive : async () -> T) -> T {
  @async.with_timeout(TEST_RECEIVE_TIMEOUT_MS, receive)
}
