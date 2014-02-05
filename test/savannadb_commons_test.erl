%%======================================================================
%%
%% LeoProject - SavannaDB Commons
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
-module(savannadb_commons_test).
-author('Yosuke Hara').

-include("savannadb_commons.hrl").
-include_lib("eunit/include/eunit.hrl").


suite_test_() ->
    {setup,
     fun () ->
             folsom:start(),
             mnesia:start(),
             {ok,_Pid} = svdbc_sup:start_link(),
             ok
     end,
     fun (_) ->
             folsom:stop(),
             mnesia:stop()
     end,
     [{"test sliding counter-metrics",
       {timeout, 30, fun counter_metrics/0}},
      {"test sliding histogram",
       {timeout, 30, fun histogram/0}},
      {"test creating schema",
       {timeout, 30, fun create_schema/0}},
      {"test creating metrics by a schema",
       {timeout, 30, fun create_metrics_by_shcema/0}}
     ]}.

counter_metrics() ->
    Schema = 'test',
    Key = 'c1',
    Window = 10,
    Callback = fun({_Schema, _Key, _Value}) ->
                       ?debugVal({_Schema, _Key}),
                       ?debugVal(_Value),
                       ok
               end,
    savannadb_commons:new(?METRIC_COUNTER, Schema, Key, Window, Callback),
    savannadb_commons:notify(Schema, {Key, 128}),
    savannadb_commons:notify(Schema, {Key, 256}),
    savannadb_commons:notify(Schema, {Key, 384}),
    savannadb_commons:notify(Schema, {Key, 512}),
    {ok, Ret_1} = savannadb_commons:get_metric_value(Schema, Key),
    ?assertEqual([{count,1280},{one,1280}], Ret_1),

    %% @TODO - check sent value into the db
    timer:sleep(Window * 2000 + 100),
    {ok, Ret_2} = savannadb_commons:get_metric_value(Schema, Key),
    ?assertEqual([{count,1280},{one,0}], Ret_2),
    ok.

histogram() ->
    Schema = 'test',
    Key = 'h1',
    Window = 10,
    Callback = fun({_Schema, _Key,_Value}) ->
                       ?debugVal({_Schema, _Key}),
                       ?debugVal(_Value),
                       ok
               end,
    savannadb_commons:new(?METRIC_HISTOGRAM, ?HISTOGRAM_SLIDE, Schema, Key, Window, Callback),
    savannadb_commons:notify(Schema, {Key,  16}),
    savannadb_commons:notify(Schema, {Key,  32}),
    savannadb_commons:notify(Schema, {Key,  64}),
    savannadb_commons:notify(Schema, {Key, 128}),
    savannadb_commons:notify(Schema, {Key, 128}),
    savannadb_commons:notify(Schema, {Key, 256}),
    savannadb_commons:notify(Schema, {Key, 512}),

    {ok, Ret} = savannadb_commons:get_metric_value(Schema, Key),
    ?assertEqual([16,32,64,128,128,256,512], Ret),

    {ok, Ret_1} = savannadb_commons:get_histogram_statistics(Schema, Key),
    ?assertEqual(16,  leo_misc:get_value('min',    Ret_1)),
    ?assertEqual(512, leo_misc:get_value('max',    Ret_1)),
    ?assertEqual(128, leo_misc:get_value('median', Ret_1)),
    ?assertEqual(7,   leo_misc:get_value('n',      Ret_1)),

    %% @TODO - check sent value into the db
    timer:sleep(Window * 2000 + 100),
    {ok, Ret_2} = savannadb_commons:get_histogram_statistics(Schema, Key),
    ?assertEqual(0.0, leo_misc:get_value('min',    Ret_2)),
    ?assertEqual(0.0, leo_misc:get_value('max',    Ret_2)),
    ?assertEqual(0.0, leo_misc:get_value('median', Ret_2)),
    ?assertEqual(0,   leo_misc:get_value('n',      Ret_2)),
    ok.

create_schema() ->
    SchemaName = 'test_1',
    {atomic,ok} = svdbc_tbl_schema:create_table(ram_copies, [node()]),
    {atomic,ok} = svdbc_tbl_column:create_table(ram_copies, [node()]),

    not_found = svdbc_tbl_column:all(),
    ok = savannadb_commons:create_schema(
           SchemaName, [#svdb_column{name = 'col_1',
                                     type = ?COL_TYPE_COUNTER,
                                     constraint = [{min, 0}, {max, 16384}]},
                        #svdb_column{name = 'col_2',
                                     type = ?COL_TYPE_H_SLIDE,
                                     constraint = []},
                        #svdb_column{name = 'col_3',
                                     type = ?COL_TYPE_H_SLIDE,
                                     constraint = []}
                       ]),

    {ok, Columns_1} = svdbc_tbl_column:all(),
    {ok, Columns_2} = svdbc_tbl_column:find_by_schema_name(SchemaName),
    ?assertEqual(true, Columns_1 == Columns_2),
    ?assertEqual(3, svdbc_tbl_column:size()),
    ok.

create_metrics_by_shcema() ->
    Schema = 'test_1',
    Window = 10,
    Callback = fun({_Schema, _Key, _Value}) ->
                       ?debugVal({_Schema, _Key}),
                       ?debugVal(_Value),
                       ok
               end,
    ok = savannadb_commons:create_metrics_by_schema(Schema, Window, Callback),
    Key_1 = 'col_1',
    savannadb_commons:notify(Schema, {Key_1, 128}),
    savannadb_commons:notify(Schema, {Key_1, 256}),
    savannadb_commons:notify(Schema, {Key_1, 384}),
    savannadb_commons:notify(Schema, {Key_1, 512}),

    Key_2 = 'col_2',
    savannadb_commons:notify(Schema, {Key_2,  16}),
    savannadb_commons:notify(Schema, {Key_2,  32}),
    savannadb_commons:notify(Schema, {Key_2,  64}),
    savannadb_commons:notify(Schema, {Key_2, 128}),
    savannadb_commons:notify(Schema, {Key_2, 128}),
    savannadb_commons:notify(Schema, {Key_2, 256}),
    savannadb_commons:notify(Schema, {Key_2, 512}),

    Key_3 = 'col_3',
    savannadb_commons:notify(Schema, {Key_3, erlang:phash2(leo_date:clock())}),
    savannadb_commons:notify(Schema, {Key_3, erlang:phash2(leo_date:clock())}),
    savannadb_commons:notify(Schema, {Key_3, erlang:phash2(leo_date:clock())}),
    savannadb_commons:notify(Schema, {Key_3, erlang:phash2(leo_date:clock())}),
    savannadb_commons:notify(Schema, {Key_3, erlang:phash2(leo_date:clock())}),
    savannadb_commons:notify(Schema, {Key_3, erlang:phash2(leo_date:clock())}),
    savannadb_commons:notify(Schema, {Key_3, erlang:phash2(leo_date:clock())}),
    savannadb_commons:notify(Schema, {Key_3, erlang:phash2(leo_date:clock())}),
    savannadb_commons:notify(Schema, {Key_3, erlang:phash2(leo_date:clock())}),

    {ok, Ret_1} = savannadb_commons:get_metric_value(Schema, Key_1),
    {ok, Ret_2} = savannadb_commons:get_histogram_statistics(Schema, Key_2),
    {ok, Ret_3} = savannadb_commons:get_histogram_statistics(Schema, Key_3),
    ?assertEqual([{count,1280},{one,1280}], Ret_1),
    ?assertEqual(16,  leo_misc:get_value('min',    Ret_2)),
    ?assertEqual(512, leo_misc:get_value('max',    Ret_2)),
    ?assertEqual(128, leo_misc:get_value('median', Ret_2)),
    ?assertEqual(7,   leo_misc:get_value('n',      Ret_2)),
    ?assertEqual(true, [] /= Ret_3),

    timer:sleep(Window * 2000 + 100),
    ok.