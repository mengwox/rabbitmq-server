%%   The contents of this file are subject to the Mozilla Public License
%%   Version 1.1 (the "License"); you may not use this file except in
%%   compliance with the License. You may obtain a copy of the License at
%%   http://www.mozilla.org/MPL/
%%
%%   Software distributed under the License is distributed on an "AS IS"
%%   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%%   License for the specific language governing rights and limitations
%%   under the License.
%%
%%   The Original Code is RabbitMQ Management Console.
%%
%%   The Initial Developer of the Original Code is VMware, Inc.
%%   Copyright (c) 2010-2012 VMware, Inc.  All rights reserved.
%%

-module(rabbit_mgmt_test_db_unit).

-include("rabbit_mgmt.hrl").
-include_lib("eunit/include/eunit.hrl").

remove_old_samples_test() ->
    T = fun (Before, After) ->
                ?assertEqual(After, unstats(rabbit_mgmt_db:remove_old_samples(
                                              cutoff(), stats(Before))))
        end,
    %% Cut off old sample, move to base
    T({[{8999, 123}, {9000, 456}], 0},
      {[{9000, 456}], 123}),
    %% Amalgamate old samples to rounder one
    T({[{9000, 100}, {9001, 020}, {9010, 003}], 0},
      {[{9000, 123}], 0}),
    %% The same, but a bit less
    T({[{9000, 100}, {9901, 020}, {9910, 003}], 0},
      {[{9000, 120}, {9910, 003}], 0}),
    %% Nothing needs to be done
    T({[{9000, 100}, {9990, 020}, {9991, 003}], 0},
      {[{9000, 100}, {9990, 020}, {9991, 003}], 0}),
    %% Invent a new older sample that's acceptable
    T({[{9001, 10}, {9010, 02}], 0},
      {[{9000, 12}], 0}),
    %% ...but don't if it's too old
    T({[{8001, 10}, {8010, 02}], 0},
      {[], 12}),
    ok.

format_sample_details_test() ->
    T = fun ({First, Last, Incr}, Stats, Results) ->
                ?assertEqual(format(Results),
                             rabbit_mgmt_db:format_sample_details(
                                        #range{first = First * 1000,
                                               last  = Last * 1000,
                                               incr  = Incr * 1000},
                                        stats(Stats)))
        end,
    %% Just three samples, all of which we format
    T({10, 30, 10}, {[{10, 10}, {20, 20}, {30, 30}], 1},
      {[{30, 61}, {20, 31}, {10, 11}], 3.0, 10, 2.5, 61}),

    %% Skip over the second
    T({10, 30, 20}, {[{10, 10}, {20, 20}, {30, 30}], 1},
      {[{30, 61}, {10, 11}], 2.5, 20, 2.5, 61}),

    %% Skip over some and invent some
    %% TODO this rate calculation is dodgy, we should change it!
    T({0, 40, 20}, {[{10, 10}, {20, 20}, {30, 30}], 1},
      {[{40, 61}, {20, 31}, {0, 1}], 1.5, 20, 1.5, 61}),

    %% TODO more?
    ok.

%%--------------------------------------------------------------------

cutoff() ->
    {[{10, 1}, {100, 10}, {1000, 100}], %% Sec
     10000000}. %% Millis

stats({Diffs, Base}) ->
    #stats{diffs = gb_trees:from_orddict(secs_to_millis(Diffs)), base = Base}.

unstats(#stats{diffs = Diffs, base = Base}) ->
    {millis_to_secs(gb_trees:to_list(Diffs)), Base}.

secs_to_millis(L) -> [{TS * 1000, S} || {TS, S} <- L].
millis_to_secs(L) -> [{TS div 1000, S} || {TS, S} <- L].

format({Samples, Rate, Interval, AvgRate, Count}) ->
    {[{rate,     Rate},
      {interval, Interval * 1000},
      {avg_rate, AvgRate},
      {samples, [[{sample, S}, {timestamp, TS * 1000}] || {TS, S} <- Samples]}],
     Count}.

