// import bravo
// import bravo/uset
// import gleam/bit_array
// import gleam/bytes_tree
// import gleam/dynamic
// import gleam/erlang/process.{type Subject}
// import gleam/function
// import gleam/http
// import gleam/http/request.{type Request}
// import gleam/http/response.{type Response}
// import gleam/io
// import gleam/list
// import gleam/option.{None, Some}
// import gleam/otp/actor
// import gleam/result
// import gleam/string_tree
// import mist
// import simplifile
// import sqlight

// import mist/internal/websocket.{type WebsocketConnection}

// fn new_response(status: Int, body: String) {
//   response.new(status)
//   |> response.set_body(body |> bytes_tree.from_string |> mist.Bytes)
// }

// pub fn main() {
//   let assert Ok(connected_users_table) =
//     uset.new("ConnectedUsers", 1, bravo.Public)
//   use conn <- sqlight.with_connection("file:database/db.sqlite")
//   let document_decoder = dynamic.tuple2(dynamic.string, dynamic.string)

//   let sql =
//     "create table if not exists documents (name PRIMARY KEY, value text);
//     insert or ignore into documents (name, value) VALUES ('document', '');
// "
//   let assert Ok(Nil) = sqlight.exec(sql, conn)
//   let state = Nil
//   let assert Ok(_) =
//     mist.new(fn(request) {
//       let response = case request.path_segments(request) {
//         [] -> {
//           use index <- result.try(
//             simplifile.read("dist/index.html")
//             |> result.replace_error("Could not read index.html."),
//           )
//           Ok(new_response(200, index))
//         }
//         ["ws"] -> {
//           Ok(mist.websocket(
//             request: request,
//             on_init: fn(_connection) {
//               let subject = process.new_subject()

//               case uset.insert(connected_users_table, [#(subject)]) {
//                 True -> io.println("added new user to database !")
//                 False -> io.println("error couldn't add user to database !")
//               }

//               #(State(subject, connected_users_table), None)
//             },
//             on_close: fn(state) {
//               // let connection = case State(connection, connected_users_table) {
//               //   State(connection, connected_users_table) -> connection
//               // }
//               //  State(connection:, table:) 
//               let current_connection = case state {
//                 State(connection, _table) -> connection
//               }
//               uset.delete_object(connected_users_table, #(current_connection))

//               io.println("goodbye!")
//             },
//             handler: handle_ws_message,
//           ))
//         }
//         _ -> {
//           new_response(404, "Not found") |> Ok
//         }
//       }

//       case response {
//         Ok(response) -> response
//         Error(error) -> {
//           io.print_error(error)
//           new_response(500, "Internal Server Error")
//         }
//       }
//     })
//     |> mist.bind("0.0.0.0")
//     |> mist.port(3000)
//     |> mist.start_http_server

//   process.sleep_forever()
// }

// pub type MyMessage {
//   Broadcast(String)
// }

// pub type State {
//   State(client: Subject(State), table: uset.USet(#(Subject(State))))
// }

// fn handle_ws_message(state, conn, message) {
//   // io.debug(message)
//   // io.debug(state)
//   let table = case state {
//     State(_connection, table) -> table
//   }
//   case message {
//     mist.Text("ping") -> {
//       let assert Ok(_) = mist.send_text_frame(conn, "pong")

//       actor.continue(state)
//     }
//     mist.Text(value) -> {
//       uset.tab2list(table)
//       |> list.map(fn(subject) {
//         let #(subject) = subject
//         // let assert Ok(_) = mist.send_text_frame(subject, value)
//         subject
//         |> process.send(handle_ws_message(
//           state,
//           conn,
//           mist.Custom(Broadcast(value)),
//         ))
//         // io.debug("sent message to :")
//         // io.debug(conn)
//         // actor.send())
//       })
//       actor.continue(state)
//     }
//     mist.Custom(Broadcast(text)) -> {
//       let assert Ok(_) = mist.send_text_frame(conn, text)
//       actor.continue(state)
//     }
//     mist.Closed | mist.Shutdown -> actor.Stop(process.Normal)
//     mist.Binary(_) -> actor.continue(state)
//   }
// }
import actors/websocket_actor
import artifacts/pubsub.{type Channel, Awareness, Doc}

import chip
import gleam/bytes_tree
import gleam/erlang/process.{type Selector, type Subject}
import gleam/http/request
import gleam/http/response

import gleam/io

// import gleam/option.{type Option, None, Some}

import gleam/result
import mist
import simplifile

fn new_response(status: Int, body: String) {
  response.new(status)
  |> response.set_body(body |> bytes_tree.from_string |> mist.Bytes)
}

pub fn main() {
  let assert Ok(pubsub) = pubsub.start()
  let assert Ok(_) =
    mist.new(fn(request) {
      let response = case request.path_segments(request) {
        [] -> {
          use index <- result.try(
            simplifile.read("dist/index.html")
            |> result.replace_error("Could not read index.html."),
          )
          Ok(new_response(200, index))
        }
        ["doc"] -> {
          Ok(websocket_actor.start(request, pubsub, Doc))
        }
        ["awareness"] -> {
          Ok(websocket_actor.start(request, pubsub, Awareness))
        }
        _ -> {
          new_response(404, "Not found") |> Ok
        }
      }

      case response {
        Ok(response) -> response
        Error(error) -> {
          io.print_error(error)
          new_response(500, "Internal Server Error")
        }
      }
    })
    |> mist.bind("0.0.0.0")
    |> mist.port(3000)
    |> mist.start_http_server

  process.sleep_forever()
}
