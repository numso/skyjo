defmodule Skyjo.Game do
  alias Skyjo.{Game, Games}

  defstruct code: nil,
            state: nil,
            players: [],
            deck: [],
            discard: [],
            cur_player: nil,
            cur_card: nil,
            out_player: nil

  def create() do
    player = new_player()
    game = %Game{code: new_code(), state: :lobby, players: [player]}
    :ok = Games.set_game(game)
    {player, game}
  end

  defp new_player() do
    %{
      code: new_code(),
      name: "player",
      cards: [],
      scores: [],
      active?: true,
      ready?: false
    }
  end

  def join(code) when code in ["", nil], do: {:error, :code_missing}

  def join(code) do
    case Games.get_game(code) do
      nil ->
        {:error, :game_missing}

      game when game.state not in [:lobby, :round_finished, :game_finished] ->
        {:error, :game_in_progress}

      game ->
        if game.players |> active_players() |> length() == 8 do
          {:error, :full_game}
        else
          player =
            if game.state == :lobby do
              new_player()
            else
              my_scores =
                game.players
                |> List.first()
                |> Map.get(:scores)
                |> Enum.map(fn _ -> {0, :inactive} end)

              # TODO:: pop off the last score, put in the average instead with some tag signifying such
              %{new_player() | scores: my_scores}
            end

          new_game = %Game{game | players: [player | game.players]}
          :ok = Games.set_game(new_game)
          {:ok, {player, new_game}}
        end
    end
  end

  def transition(game, pid, action) do
    do_transition(game, pid, action) |> Games.set_game()
  end

  defp do_transition(%Game{} = game, pid, {:rename, name}) do
    player_index = Enum.find_index(game.players, &(&1.code == pid))
    player = Enum.at(game.players, player_index)
    new_player = %{player | name: name}
    %{game | players: List.replace_at(game.players, player_index, new_player)}
  end

  defp do_transition(%Game{state: :lobby, players: players} = game, _, :start) do
    if players |> active_players() |> length() < 2 do
      game
    else
      # TODO:: only host can start the game
      start_game(game, true)
    end
  end

  defp do_transition(%Game{state: :lobby} = game, _, {:kick, pid}) do
    # TODO:: only host can kick others
    # TODO:: if no active players are left, remove the game
    Games.broadcast(game.code, {:player_kicked, pid})
    %{game | players: Enum.reject(game.players, &(&1.code == pid))}
  end

  defp do_transition(%Game{state: :start} = game, pid, {:reveal, i}) do
    if player_ready?(game, pid) do
      game
    else
      game
      |> update_cards(pid, &List.update_at(&1, i, fn {i, num, _} -> {i, num, :revealed} end))
      |> check_readiness()
    end
  end

  defp do_transition(%Game{state: :draw, cur_player: pid} = game, pid, :take_discard) do
    [card | discard] = game.discard
    %Game{game | state: :discard, cur_card: card, discard: discard}
  end

  defp do_transition(%Game{state: :draw, cur_player: pid} = game, pid, :take_deck) do
    case game.deck do
      [card | []] ->
        %Game{
          game
          | state: :discard,
            cur_card: card,
            discard: [],
            deck: Enum.shuffle(game.discard)
        }

      [card | deck] ->
        %Game{game | state: :discard, cur_card: card, deck: deck}
    end
  end

  defp do_transition(%Game{state: :discard, cur_player: pid} = game, pid, :discard) do
    %Game{game | state: :reveal, cur_card: nil, discard: [game.cur_card | game.discard]}
  end

  defp do_transition(%Game{state: :discard, cur_player: pid} = game, pid, {:drop, i}) do
    case get_card(game, pid, i) do
      {_, _, :duplicate} ->
        game

      {_, card, _} ->
        game
        |> update_cards(&List.replace_at(&1, i, {i, game.cur_card, :revealed}))
        |> update_state(:draw)
        |> (fn game -> %Game{game | cur_card: nil, discard: [card | game.discard]} end).()
        |> check_endgame()
        |> remove_duplicates()
        |> (fn game -> %Game{game | cur_player: next_player(game)} end).()
        |> double_check_endgame()
    end
  end

  defp do_transition(%Game{state: :reveal, cur_player: pid} = game, pid, :undo) do
    [cur_card | discard] = game.discard
    %Game{game | state: :discard, cur_card: cur_card, discard: discard}
  end

  defp do_transition(%Game{state: :reveal, cur_player: pid} = game, pid, {:reveal, i}) do
    case get_card(game, pid, i) do
      {_, _, :hidden} ->
        game
        |> update_cards(&List.update_at(&1, i, fn {i, num, _} -> {i, num, :revealed} end))
        |> update_state(:draw)
        |> check_endgame()
        |> remove_duplicates()
        |> (fn game -> %Game{game | cur_player: next_player(game)} end).()
        |> double_check_endgame()

      _ ->
        game
    end
  end

  defp do_transition(%Game{state: :round_finished} = game, _, {:kick, pid}) do
    # TODO:: only host can kick others
    # TODO:: if no active players are left, remove the game
    Games.broadcast(game.code, {:player_kicked, pid})
    player_index = Enum.find_index(game.players, &(&1.code == pid))
    player = Enum.at(game.players, player_index)
    new_player = %{player | active?: false}
    new_game = %{game | players: List.replace_at(game.players, player_index, new_player)}

    if new_game.cur_player == player.code do
      %{new_game | cur_player: nil}
    else
      new_game
    end
  end

  defp do_transition(%Game{state: :round_finished} = game, pid, :ready) do
    player_index = Enum.find_index(game.players, &(&1.code == pid))
    player = Enum.at(game.players, player_index)
    new_player = %{player | ready?: true}
    new_game = %{game | players: List.replace_at(game.players, player_index, new_player)}

    if new_game.players |> active_players() |> Enum.all?(& &1.ready?) do
      new_players = Enum.map(new_game.players, fn player -> %{player | ready?: false} end)
      start_game(%Game{new_game | players: new_players}, false)
    else
      new_game
    end
  end

  defp do_transition(%Game{state: :game_finished} = game, _, {:kick, pid}) do
    # TODO:: only host can kick others
    # TODO:: if no active players are left, remove the game
    Games.broadcast(game.code, {:player_kicked, pid})
    player_index = Enum.find_index(game.players, &(&1.code == pid))
    player = Enum.at(game.players, player_index)
    new_player = %{player | active?: false}
    %{game | players: List.replace_at(game.players, player_index, new_player)}
  end

  defp do_transition(%Game{state: :game_finished} = game, pid, :ready) do
    player_index = Enum.find_index(game.players, &(&1.code == pid))
    player = Enum.at(game.players, player_index)
    new_player = %{player | ready?: true}
    new_game = %{game | players: List.replace_at(game.players, player_index, new_player)}

    if new_game.players |> active_players |> Enum.all?(& &1.ready?) do
      new_players =
        Enum.map(new_game.players, fn player -> %{player | ready?: false, scores: []} end)

      start_game(%Game{new_game | players: new_players, cur_player: nil}, true)
    else
      new_game
    end
  end

  defp do_transition(game, _, _), do: game

  defp new_code do
    <<:rand.uniform(1_048_576)::40>>
    |> Base.encode32()
    |> binary_part(4, 4)
  end

  defp active_players(players) do
    Enum.filter(players, & &1.active?)
  end

  defp start_game(game, is_new?) do
    deck = get_deck() |> Enum.shuffle()
    active_players = Enum.filter(game.players, & &1.active?)
    {piles, [discard | deck]} = deal_cards(deck, length(active_players))
    players = if is_new?, do: active_players, else: game.players

    {players, []} =
      Enum.reduce(players, {[], piles}, fn
        %{active?: false} = player, {players, piles} ->
          {[player | players], piles}

        player, {players, [cards | piles]} ->
          {[
             %{
               player
               | cards:
                   cards |> Enum.with_index() |> Enum.map(fn {num, i} -> {i, num, :hidden} end)
             }
             | players
           ], piles}
      end)

    %Game{game | state: :start, deck: deck, discard: [discard], players: Enum.reverse(players)}
  end

  defp get_deck do
    Enum.flat_map(
      -2..12,
      fn
        -2 -> List.duplicate(-2, 5)
        0 -> List.duplicate(0, 15)
        i -> List.duplicate(i, 10)
      end
    )
  end

  defp deal_cards(deck, count) do
    {cards, rest} = Enum.split(deck, count * 12)
    {Enum.chunk_every(cards, 12), rest}
  end

  defp next_player(game) do
    player_index = Enum.find_index(game.players, &(&1.code == game.cur_player))
    player = Enum.at(game.players, player_index - 1, List.last(game.players))

    if player.active? do
      player.code
    else
      next_player(%{game | cur_player: player.code})
    end
  end

  defp player_ready?(%Game{players: players}, pid) do
    players
    |> Enum.find(&(&1.code == pid))
    |> Map.get(:cards)
    |> Enum.count(fn {_i, _num, state} -> state == :revealed end) == 2
  end

  defp check_readiness(%Game{players: players, cur_player: nil} = game) do
    if players |> active_players() |> Enum.all?(&player_ready?(game, &1.code)) do
      player =
        game.players
        |> active_players()
        |> Enum.sort_by(&get_score(game, &1.code))
        |> List.last()

      %Game{game | state: :draw, cur_player: player.code}
    else
      game
    end
  end

  defp check_readiness(%Game{players: players} = game) do
    if players |> active_players() |> Enum.all?(&player_ready?(game, &1.code)) do
      %Game{game | state: :draw}
    else
      game
    end
  end

  defp check_endgame(%Game{out_player: nil} = game) do
    out_player = if fully_revealed?(game), do: game.cur_player
    %Game{game | out_player: out_player}
  end

  defp check_endgame(game) do
    update_cards(
      game,
      &Enum.map(&1, fn
        {i, num, :hidden} -> {i, num, :revealed}
        card -> card
      end)
    )
  end

  defp remove_duplicates(%Game{cur_player: pid} = game) do
    chunks =
      game.players
      |> Enum.find(&(&1.code == pid))
      |> Map.get(:cards)
      |> Enum.chunk_every(3)

    new_duplicates =
      chunks
      |> Enum.filter(&duplicate_cards?/1)
      |> List.flatten()
      |> Enum.map(fn {_, num, _} -> num end)

    %Game{game | discard: new_duplicates ++ game.discard}
    |> update_cards(fn cards ->
      cards
      |> Enum.chunk_every(3)
      |> Enum.map(fn cardset ->
        case duplicate_cards?(cardset) do
          true -> Enum.map(cardset, fn {i, _, _} -> {i, "", :duplicate} end)
          false -> cardset
        end
      end)
      |> List.flatten()
    end)
  end

  defp duplicate_cards?([{_, a, :revealed}, {_, a, :revealed}, {_, a, :revealed}]), do: true
  defp duplicate_cards?(_), do: false

  defp double_check_endgame(%Game{out_player: p, cur_player: p} = game) do
    game
    |> tally_round_scores(p)
    |> set_finished_state()
  end

  defp double_check_endgame(game), do: game

  defp tally_round_scores(%Game{} = game, pid) do
    scores =
      game.players |> active_players() |> Enum.map(&get_score(game, &1.code)) |> Enum.sort()

    p_score = get_score(game, pid)

    should_double =
      p_score > 0 and
        case scores do
          [a, a | _] -> true
          [^p_score | _] -> false
          _ -> true
        end

    new_players =
      Enum.map(game.players, fn player ->
        score =
          case {get_score(game, player.code), player, should_double} do
            {score, %{code: ^pid}, true} -> {score, :doubled}
            {score, %{code: ^pid}, _} -> {score, :first}
            {_, %{active?: false}, _} -> {0, :inactive}
            {score, _, _} -> score
          end

        %{player | scores: [score | player.scores]}
      end)

    %Game{game | players: new_players}
  end

  defp set_finished_state(%Game{players: players} = game) do
    max_score =
      players
      |> active_players()
      |> Enum.map(&sum_scores(&1.scores))
      |> Enum.sort()
      |> List.last()

    next_state = if max_score >= 100, do: :game_finished, else: :round_finished
    %Game{game | state: next_state, out_player: nil}
  end

  def sum_scores(scores) do
    scores
    |> Enum.map(fn
      {num, :doubled} -> num * 2
      {num, :first} -> num
      {_, :inactive} -> 0
      num -> num
    end)
    |> Enum.sum()
  end

  def render_score({num, :doubled}), do: "#{num} x 2"
  def render_score({_, :inactive}), do: ""
  def render_score({num, _}), do: num
  def render_score(num), do: num

  defp fully_revealed?(%Game{players: players, cur_player: pid}) do
    players
    |> Enum.find(&(&1.code == pid))
    |> Map.get(:cards)
    |> Enum.all?(fn {_, _, state} -> state != :hidden end)
  end

  defp update_cards(%Game{cur_player: pid} = game, update), do: update_cards(game, pid, update)

  defp update_cards(%Game{} = game, pid, update) do
    player_index = Enum.find_index(game.players, &(&1.code == pid))
    player = Enum.at(game.players, player_index)
    new_player = %{player | cards: update.(player.cards)}
    %{game | players: List.replace_at(game.players, player_index, new_player)}
  end

  defp update_state(%Game{} = game, state) do
    %Game{game | state: state}
  end

  defp get_card(%Game{players: players}, pid, i) do
    players
    |> Enum.find(&(&1.code == pid))
    |> Map.get(:cards)
    |> Enum.find(fn {index, _, _} -> index == i end)
  end

  defp get_score(%Game{players: players}, pid) do
    players
    |> Enum.find(&(&1.code == pid))
    |> Map.get(:cards)
    |> Enum.filter(fn {_, _, state} -> state == :revealed end)
    |> Enum.map(fn {_, num, _} -> num end)
    |> Enum.sum()
  end
end
