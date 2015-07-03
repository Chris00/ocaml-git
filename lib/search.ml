(*
 * Copyright (c) 2013-2015 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Lwt.Infix

let err_not_found n k =
  let str = Printf.sprintf "Git.Search.%s: %s not found" n k in
  Lwt.fail (Invalid_argument str)

type succ =
  [ `Commit of SHA.t
  | `Tag of string * SHA.t
  | `Tree of string * SHA.t ]

let sha1_of_succ = function
  | `Commit s
  | `Tag (_, s)
  | `Tree (_, s) -> s

module Make (Store: Store.S) = struct

  type path = string list

  let succ t sha1 =
    let commit c =
      `Commit (SHA.of_commit c) in
    let tree l s =
      `Tree (l, SHA.of_tree s) in
    let tag t =
      `Tag (t.Tag.tag, t.Tag.sha1) in
    Store.read t sha1 >>= function
    | None                  -> Lwt.return_nil
    | Some (Value.Blob _)   -> Lwt.return_nil
    | Some (Value.Commit c) ->
      Lwt.return (tree "" c.Commit.tree :: List.map commit c.Commit.parents)
    | Some (Value.Tag t)    -> Lwt.return [tag t]
    | Some (Value.Tree t)   ->
      Lwt.return (List.map (fun e -> `Tree (e.Tree.name, e.Tree.node)) t)

  (* XXX: not tail-rec *)
  let rec find t sha1 path =
    match path with
    | []   -> Lwt.return (Some sha1)
    | h::p ->
      succ t sha1 >>= fun succs ->
      Lwt_list.fold_left_s (fun acc s ->
          match (acc, s) with
          | Some _, _            -> Lwt.return acc
          | _     , `Commit _    -> Lwt.return acc
          | _     , `Tag (l, s)
          | _     , `Tree (l, s) ->
            if l = h then
              find t s p >>= function
              | None   -> Lwt.return_none
              | Some f -> Lwt.return (Some f)
            else
              Lwt.return acc
        ) None succs


  let find_exn t sha1 path =
    find t sha1 path >>= function
    | Some x -> Lwt.return x
    | None   -> err_not_found "find_exn" (SHA.pretty sha1)

  (* XXX: can do one less look-up *)
  let mem t sha1 path =
    find t sha1 path >>= function
    | None   -> Lwt.return false
    | Some _ -> Lwt.return true

end
