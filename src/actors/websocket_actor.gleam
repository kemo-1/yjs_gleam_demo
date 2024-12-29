import actors/actor_messages.{
  type CustomWebsocketMessage, Connect, Disconnect, SendToAll,
}
import artifacts/pubsub.{type Channel}
import chip
import gleam/erlang/process.{type Subject, Normal}
import gleam/function
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/list
import gleam/option.{Some}
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
  )
}

pub fn start(
  req: Request(Connection),
  pubsub,
  channel: Channel,
) -> Response(ResponseData) {
  mist.websocket(
    request: req,
    on_init: fn(_) {
      io.println("New connection initialized")

      let ws_subject = process.new_subject()
      let new_selector =
        process.new_selector()
        |> process.selecting(ws_subject, function.identity)
      chip.register(pubsub, channel, ws_subject)
      let state = WebsocketActorState(ws_subject: pubsub, channel: channel)

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
        Connect(subject) -> {
          //   send_client_text(connection, "joined")

          state |> actor.continue
        }
        SendToAll(message) -> {
          send_client_text(connection, message)
          state |> actor.continue
        }
        Disconnect -> {
          state |> actor.continue
        }
      }

    Text(value) -> {
      chip.members(state.ws_subject, state.channel, 50)
      |> list.each(fn(client) {
        SendToAll(message: value)
        |> process.send(client, _)
      })

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
