import gleam/erlang/process.{type Subject}

pub type CustomWebsocketMessage {
  Connect(user_subject: Subject(CustomWebsocketMessage))
  SendToAll(message: String)
  Disconnect
}
