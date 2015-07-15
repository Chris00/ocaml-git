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

(** Pack files. *)

type t = (SHA.t * Packed_value.PIC.t) list
(** A pack value is an ordered list of position-independant packed
    values and the SHA of the corresponding inflated objects. *)

include Object.S with type t := t

val input:
  read:(SHA.t -> Value.t option Lwt.t) -> Mstruct.t ->
  index:Pack_index.Raw.t option -> t Lwt.t
(** The usual [Object.S.input] function, but with additionals [read]
    and [index] arguments. When [index] is [None], recompute the whole
    index: that's very costly so provide the index when possible. *)

val keys: t -> SHA.Set.t
(** Return the keys present in the pack. *)

val read: t -> SHA.t -> Value.t option
(** Return the value stored in the pack file. *)

val read_exn: t -> SHA.t -> Value.t
(** Return the value stored in the pack file. *)

val unpack:
  read:(SHA.t -> Value.t option Lwt.t) -> write:(Value.t -> SHA.t Lwt.t) ->
  Cstruct.t -> SHA.Set.t Lwt.t
(** Unpack a whole pack file. [write] should returns the SHA of the
    marshaled value. Return the IDs of the written objects. *)

val pack: (SHA.t * Value.t) list -> t
(** Create a (compressed) pack file. *)

module Raw: sig

  (** Raw pack file: they contains a pack index and a list of
      position-dependant deltas. *)

  include Object.S

  val input: Mstruct.t -> index:Pack_index.Raw.t option -> t
  (** Same as the top-level [input] function but for raw packs. *)

  val sha1: t -> SHA.t
  (** Return the name of the pack. *)

  val index: t -> Pack_index.Raw.t
  (** Return the pack index. *)

  val keys: t -> SHA.Set.t
  (** Return the keys present in the raw pack. *)

  val buffer: t -> Cstruct.t
  (** Return the pack buffer. *)

  val read: read:(SHA.t -> Value.t option Lwt.t) -> Mstruct.t -> Pack_index.t ->
    SHA.t -> Value.t option Lwt.t
  (** Same as the top-level [read] function but for raw packs. *)

end

val to_pic: read:(SHA.t -> Value.t option Lwt.t) -> Raw.t -> t Lwt.t
(** Transform a raw pack file into a position-independant pack
    file. *)

val of_pic: t -> Raw.t
(** Transform a position-independant pack file into a raw one. *)
