(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2016.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

(** IO Scheduling. This module implements generic IO scheduling
    between file descriptors. In order to use IO scheduling, the
    [register] function must be used to make a file descriptor managed
    by a [scheduler].. It will return a value of type [connection]
    that must be used to perform IO on the managed file descriptor
    using this module's dedicated IO functions (read, write, etc.).

    Each connection is allowed a read (resp. write) quota, which is
    for now fairly distributed among connections.

    To each connection is associated a read (resp. write) queue where
    data is copied to (resp. read from), at a rate of
    max_download_speed / num_connections (resp. max_upload_speed /
    num_connections).
*)

open P2p_types

type connection
(** Type of a connection. *)

type t
(** Type of an IO scheduler. *)

val create:
  ?max_upload_speed:int ->
  ?max_download_speed:int ->
  ?read_queue_size:int ->
  ?write_queue_size:int ->
  read_buffer_size:int ->
  unit -> t
(** [create ~max_upload_speed ~max_download_speed ~read_queue_size
    ~write_queue_size ()] is an IO scheduler with specified (global)
    max upload (resp. download) speed, and specified read
    (resp. write) queue sizes (in bytes) for connections. *)

val register: t -> Lwt_unix.file_descr -> connection
(** [register sched fd] is a [connection] managed by [sched]. *)

type error += Connection_closed

val write: connection -> MBytes.t -> unit tzresult Lwt.t
(** [write conn msg] returns [Ok ()] when [msg] has been added to
    [conn]'s write queue, or fail with an error. *)

val write_now: connection -> MBytes.t -> bool
(** [write_now conn msg] is [true] iff [msg] has been (immediately)
    added to [conn]'s write queue, [false] if it has been dropped. *)

val read_now:
  connection -> ?pos:int -> ?len:int -> MBytes.t -> int tzresult option
(** [read_now conn ~pos ~len buf] blits at most [len] bytes from
    [conn]'s read queue and returns the number of bytes written in
    [buf] starting at [pos]. *)

val read:
  connection -> ?pos:int -> ?len:int -> MBytes.t -> int tzresult Lwt.t
(** Like [read_now], but waits till [conn] read queue has at least one
    element instead of failing. *)

val read_full:
  connection -> ?pos:int -> ?len:int -> MBytes.t -> unit tzresult Lwt.t
(** Like [read], but blits exactly [len] bytes in [buf]. *)

val stat: connection -> Stat.t
(** [stat conn] is a snapshot of current bandwidth usage for
    [conn]. *)

val global_stat: t -> Stat.t
(** [global_stat sched] is a snapshot of [sched]'s bandwidth usage
    (sum of [stat conn] for each [conn] in [sched]). *)

val iter_connection: t -> (int -> connection -> unit) -> unit
(** [iter_connection sched f] applies [f] on each connection managed
    by [sched]. *)

val close: ?timeout:float -> connection -> unit tzresult Lwt.t
(** [close conn] cancels [conn] and returns after any pending data has
    been sent. *)

val shutdown: ?timeout:float -> t -> unit Lwt.t
(** [shutdown sched] returns after all connections managed by [sched]
    have been closed and [sched]'s inner worker has successfully
    canceled. *)
