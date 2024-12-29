import actors/actor_messages.{
  type CustomWebsocketMessage, Connect, Disconnect, SendToAll,
}
import artifacts/pubsub.{type Channel, publish, subscribe}
import bravo
import bravo/uset.{type USet}
import chip
import gleam/erlang/process.{type Subject, Normal}
import gleam/function
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor.{type Next, Stop}
import mist.{
  type Connection, type ResponseData, type WebsocketConnection,
  type WebsocketMessage, Custom, Text,
}

pub type Event {
  Event(message: String)
}

pub opaque type WebsocketActorState {
  WebsocketActorState(
    ws_subject: Subject(chip.Message(CustomWebsocketMessage, Channel)),
    channel: Channel,
    table: Option(USet(#(String, String))),
  )
}

pub fn start(
  req: Request(Connection),
  pubsub,
  channel: Channel,
  table: Option(USet(#(String, String))),
) -> Response(ResponseData) {
  mist.websocket(
    request: req,
    on_init: fn(connection) {
      io.println("New connection initialized")
      let ws_subject = process.new_subject()
      let new_selector =
        process.new_selector()
        |> process.selecting(ws_subject, function.identity)
      subscribe(pubsub, channel, ws_subject)
      let state = WebsocketActorState(ws_subject: pubsub, channel:, table:)

      case table {
        Some(doc_table) -> {
          case uset.lookup(doc_table, "doc") {
            Error(_) -> Nil
            Ok(doc_table) -> {
              let #(_, doc) = doc_table
              send_client_text(connection, doc)
            }
          }
        }
        None -> Nil
      }

      #(state, Some(new_selector))
    },
    on_close: fn(_state) {
      io.println("A connection was closed")
      Nil
    },
    handler: handle_message,
  )
}

fn handle_message(
  state: WebsocketActorState,
  connection: WebsocketConnection,
  message: WebsocketMessage(CustomWebsocketMessage),
) -> Next(CustomWebsocketMessage, WebsocketActorState) {
  case message {
    Custom(message) ->
      case message {
        Connect(_subject) -> {
          state |> actor.continue
        }
        SendToAll(message) -> {
          case state.table {
            Some(table) ->
              case uset.insert(table, [#("doc", message)]) {
                True -> {
                  io.println("document have been saved in memory")
                }
                _ -> Nil
              }
            None -> Nil
          }

          send_client_text(connection, message)

          state |> actor.continue
        }
        Disconnect -> {
          Stop(Normal)
        }
      }

    Text(value) -> {
      publish(state.ws_subject, state.channel, SendToAll(message: value))

      state |> actor.continue
    }
    _ -> {
      Stop(Normal)
    }
  }
}

fn send_client_text(connection: WebsocketConnection, value: String) {
  let assert Ok(_) = mist.send_text_frame(connection, value)

  Nil
}
