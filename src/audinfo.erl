%%%-------------------------------------------------------------------
%%% File    : audinfo.erl
%%% Author  : Brendon Hogger <brendonh@dev.brendonh.org>
%%% Description : Attempt to extract metadata from audio files
%%%
%%% Created : 14 Aug 2009 by Brendon Hogger <brendonh@dev.brendonh.org>
%%%-------------------------------------------------------------------
-module(audinfo).

-export([get_info/1, test/0]).

-define(DBG(Term), io:format("~p: ~p~n", [self(), Term])).
-define(GV(E, P), proplists:get_value(E, P)).

-define(TESTFILE, "/media/everything/music/Coldplay/Misc/In My Place.mp3").
-define(TESTPATTERN, "/media/everything/music/*/*/*.mp3").


%test() ->
%    test_all(filelib:wildcard(?TESTPATTERN)).

test() ->
    test_file(?TESTFILE).

test_all([FN|Rest]) ->
    test_file(FN),
    receive after 20 -> ok end,
    test_all(Rest);
test_all([]) -> ok.

test_file(FN) ->
    {Artist, Album, Title, Track, Length} = get_info(FN),
    io:format("~.30s~.30s~.70s~.5s~.8s~n", [adjust_name(Artist),
                                            adjust_name(Album), 
                                            adjust_name(Title), 
                                            adjust_track(Track),
                                            adjust_length(Length)]).

adjust_name(undefined) -> <<"???">>;
adjust_name(Other) -> Other.
    
adjust_track(undefined) -> "";
adjust_track(Other) -> integer_to_list(Other).
    
adjust_length(undefined) -> <<"???">>;
adjust_length({Mins, Secs}) -> io_lib:format("~B:~B", [Mins, Secs]).
    


get_info(Filename) ->
    %% Given a fully qualified filename, attempt to extract
    %% its title, artist, album, and track number either from
    %% ID3, or from the filename. This assumes a file naming
    %% scheme like: Artist/Album/01 - Song Name.mp3
    Match = re:run(Filename, "^(.*)[.]([a-zA-Z0-9]+)$", [{capture, all_but_first, list}]),
    get_info(Match, Filename).

get_info(nomatch, Filename) ->
    undefined;
get_info({match, [Path, Ext]}, Filename) ->
    {Title, Artist, Album, Track, Length} = get_metadata(Ext, Filename),
    
    [File, Album2, Artist2 | Rest] = lists:reverse(string:tokens(Path, "/")),
    
    case re:run(File, "^\s*([0-9]+)[\s._-]*(.*)", [{capture, all_but_first, list}]) of
        {match, [Tr2, Ti2]} -> 
            Track2 = list_to_integer(Tr2),
            Title2 = list_to_binary(Ti2);
        nomatch -> 
            {Track2, Title2} = {undefined, list_to_binary(File)}
    end,

    {merge(Title, Title2), merge(Artist, Artist2), merge(Album, Album2), merge(Track, Track2), Length}.
             

merge(undefined, undefined) -> undefined;
merge(undefined, Something) -> Something;
merge(<<"">>,    Something) -> Something;
merge(Something, _Whatever) -> Something.


get_metadata("mp3", Filename) ->
    case id3v2:read_file(Filename) of
        {ok, P} -> 
            {?GV(tpe1, P), ?GV(talb, P), ?GV(tit2, P), get_track(?GV(trck, P)), ?GV(tlen, P)};
        not_found -> 
            {undefined, undefined, undefined, undefined, undefined}
    end;
get_metadata(_, _) ->
    {undefined, undefined, undefined, undefined, undefined}.


get_track(Bin) when byte_size(Bin) >= 1 ->
    [T|_] = string:tokens(binary_to_list(Bin), "/"),
    list_to_integer(string:strip(T));
get_track(_) -> undefined.
                    