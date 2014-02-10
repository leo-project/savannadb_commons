%% -------------------------------------------------------------------
%%
%% Copyright (c) 2011 Basho Technologies, Inc.
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
%% -------------------------------------------------------------------
%%%-------------------------------------------------------------------
%%% File:      folsom_sample_slide_server.erl
%%% @author    Russell Brown <russelldb@basho.com>
%%% @doc
%%% Serialization point for folsom_sample_slide. Handles
%%% pruning of older smaples. One started per histogram.
%%% See folsom.hrl, folsom_sample_slide, folsom_sample_slide_sup
%%% @end
%%%-----------------------------------------------------------------
-module(svdbc_sample_slide_server).

-behaviour(gen_server).

%% API
-export([start_link/3, start_link/4,
         stop/1, resize/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-include_lib("folsom/include/folsom.hrl").
-include_lib("eunit/include/eunit.hrl").

-record(state, {sample_mod,
                sample_server_id,
                reservoir,
                window}).

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------
%% Function: start_link() -> {ok,Pid} | ignore | {error,Error}
%% Description: Starts the server
start_link(SampleMod, Reservoir, Window) ->
    start_link(SampleMod, undefined, Reservoir, Window).

start_link(SampleMod, SmpleServerId, Reservoir, Window) ->
    gen_server:start_link(?MODULE, [SampleMod, SmpleServerId, Reservoir, Window], []).

stop(Pid) ->
    gen_server:cast(Pid, stop).

resize(Pid, NewWindow) ->
    gen_server:call(Pid, {resize, NewWindow}).


%%--------------------------------------------------------------------
%% GEN_SERVER CALLBACKS
%%--------------------------------------------------------------------
%% Function: init(Args) -> {ok, State}          |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%% Description: Initiates the server
init([SampleMod, SampleServerId, Reservoir, Window]) ->
    {ok, #state{sample_mod = SampleMod,
                sample_server_id = SampleServerId,
                reservoir = Reservoir,
                window = Window}, timeout(Window)}.

handle_call({resize, NewWindow}, _From, State) ->
    NewState = State#state{window = NewWindow},
    Reply = ok,
    {reply, Reply, NewState, timeout(NewWindow)};

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

handle_cast(stop, State) ->
    {stop, normal, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(timeout, State=#state{sample_mod = SampleMod,
                                  sample_server_id = undefined,
                                  reservoir = Reservoir,
                                  window = Window}) ->
    catch SampleMod:trim(Reservoir, Window),
    {noreply, State, timeout(Window)};

handle_info(timeout, State=#state{sample_mod = SampleMod,
                                  sample_server_id = SampleSeverId,
                                  reservoir = Reservoir,
                                  window = Window}) ->
    SampleMod:trim(SampleSeverId, Reservoir, Window),
    {noreply, State, timeout(Window)};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

timeout(Window) ->
    timer:seconds(Window).
