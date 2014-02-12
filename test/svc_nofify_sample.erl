%%======================================================================
%%
%% LeoProject - Savanna Commons
%%
%% Copyright (c) 2014 Rakuten, Inc.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%%======================================================================
-module(svc_nofify_sample).
-author('Yosuke Hara').

-behaviour(svc_notify_behaviour).

-include_lib("eunit/include/eunit.hrl").
-export([notify/2]).

notify(Schema, {Key, Values}) ->
    case Schema of
        'test_counter' ->
            ?debugVal({Schema, {Key, Values}});
        'test_histogram_1' ->
            ?debugVal({Schema, {Key, Values}});
        'test_histogram_2' ->
            ?debugVal({Schema, {Key, Values}});
        _ ->
            void
    end,
    ok.