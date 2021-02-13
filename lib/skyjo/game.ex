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
    player = new_player(true)
    game = %Game{code: new_code(), state: :lobby, players: [player]}
    :ok = Games.set_game(game)
    {player, game}
  end

  defp new_player(host? \\ false) do
    code = new_code()
    %{code: code, name: "player", cards: [], scores: [], host?: host?, ready?: false}
  end

  def join(code) when code in ["", nil], do: {:error, :code_missing}

  def join(code) do
    case Games.get_game(code) do
      nil ->
        {:error, :game_missing}

      game when game.state != :lobby ->
        {:error, :game_in_progress}

      %Game{players: p} when length(p) == 8 ->
        {:error, :full_game}

      game ->
        player = new_player()
        new_game = %Game{game | players: [player | game.players]}
        :ok = Games.set_game(new_game)
        {:ok, {player, new_game}}
    end
  end

  def transition(game, action) do
    do_transition(game, action)
    |> Games.set_game()
  end

  def do_transition(%Game{} = game, {pid, :rename, name}) do
    player_index = Enum.find_index(game.players, &(&1.code == pid))
    player = Enum.at(game.players, player_index)
    new_player = %{player | name: name}
    %{game | players: List.replace_at(game.players, player_index, new_player)}
  end

  def do_transition(%Game{state: :lobby, players: p} = game, _) when length(p) < 2 do
    game
  end

  def do_transition(%Game{state: :lobby} = game, _) do
    start_game(game)
  end

  def do_transition(%Game{state: :start} = game, {pid, :reveal, i}) do
    if player_ready?(game, pid) do
      game
    else
      game
      |> update_cards(pid, &List.update_at(&1, i, fn {i, num, _} -> {i, num, :revealed} end))
      |> check_readiness()
    end
  end

  def do_transition(%Game{state: :draw, cur_player: pid} = game, {pid, :take_discard}) do
    [card | discard] = game.discard
    %Game{game | state: :discard, cur_card: card, discard: discard}
  end

  def do_transition(%Game{state: :draw, cur_player: pid} = game, {pid, :take_deck}) do
    # TODO:: what happens if deck is empty?
    [card | deck] = game.deck
    %Game{game | state: :discard, cur_card: card, deck: deck}
  end

  def do_transition(%Game{state: :discard, cur_player: pid} = game, {pid, :discard}) do
    %Game{game | state: :reveal, cur_card: nil, discard: [game.cur_card | game.discard]}
  end

  def do_transition(%Game{state: :discard, cur_player: pid} = game, {pid, :reveal, i}) do
    card = get_card(game, pid, i)

    # TODO:: don't let them click on a :duplicate spot
    game
    |> update_cards(&List.replace_at(&1, i, {i, game.cur_card, :revealed}))
    |> update_state(:draw)
    |> (fn game -> %Game{game | cur_card: nil, discard: [card | game.discard]} end).()
    |> check_endgame()
    |> remove_duplicates()
    |> (fn game -> %Game{game | cur_player: next_player(game)} end).()
    |> double_check_endgame()
  end

  def do_transition(%Game{state: :reveal, cur_player: pid} = game, {pid, :reveal, i}) do
    # TODO:: don't let them click on a :duplicate spot
    # TODO:: don't let them click on a :revealed spot
    game
    |> update_cards(&List.update_at(&1, i, fn {i, num, _} -> {i, num, :revealed} end))
    |> update_state(:draw)
    |> check_endgame()
    |> remove_duplicates()
    |> (fn game -> %Game{game | cur_player: next_player(game)} end).()
    |> double_check_endgame()
  end

  def do_transition(%Game{state: :round_finished} = game, {pid, :ready}) do
    player_index = Enum.find_index(game.players, &(&1.code == pid))
    player = Enum.at(game.players, player_index)
    new_player = %{player | ready?: true}
    new_game = %{game | players: List.replace_at(game.players, player_index, new_player)}

    if Enum.all?(new_game.players, & &1.ready?) do
      new_players = Enum.map(new_game.players, fn player -> %{player | ready?: false} end)
      start_game(%Game{new_game | players: new_players})
    else
      new_game
    end
  end

  def do_transition(%Game{state: :game_finished} = game, {pid, :ready}) do
    player_index = Enum.find_index(game.players, &(&1.code == pid))
    player = Enum.at(game.players, player_index)
    new_player = %{player | ready?: true}
    new_game = %{game | players: List.replace_at(game.players, player_index, new_player)}

    if Enum.all?(new_game.players, & &1.ready?) do
      new_players =
        Enum.map(new_game.players, fn player -> %{player | ready?: false, scores: []} end)

      start_game(%Game{new_game | players: new_players, cur_player: nil})
    else
      new_game
    end
  end

  def do_transition(game, _), do: game

  defp new_code do
    <<:rand.uniform(1_048_576)::40>>
    |> Base.encode32()
    |> binary_part(4, 4)
  end

  defp start_game(game) do
    deck = get_deck() |> Enum.shuffle()
    {piles, [discard | deck]} = deal_cards(deck, length(game.players))

    players =
      Enum.zip(game.players, piles)
      |> Enum.map(fn {player, cards} ->
        %{
          player
          | cards: cards |> Enum.with_index() |> Enum.map(fn {num, i} -> {i, num, :hidden} end)
        }
      end)

    %Game{game | state: :start, deck: deck, discard: [discard], players: players}
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
    player = Enum.at(game.players, player_index + 1, List.first(game.players))
    player.code
  end

  defp player_ready?(%Game{players: players}, pid) do
    players
    |> Enum.find(&(&1.code == pid))
    |> Map.get(:cards)
    |> Enum.count(fn {_i, _num, state} -> state == :revealed end) == 2
  end

  defp check_readiness(%Game{players: players, cur_player: nil} = game) do
    if Enum.all?(players, &player_ready?(game, &1.code)) do
      player =
        game.players
        |> Enum.sort_by(&get_score(game, &1.code))
        |> List.last()

      %Game{game | state: :draw, cur_player: player.code}
    else
      game
    end
  end

  defp check_readiness(%Game{players: players} = game) do
    if Enum.all?(players, &player_ready?(game, &1.code)) do
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
    scores = Enum.map(game.players, &get_score(game, &1.code)) |> Enum.sort()
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
        score = get_score(game, player.code)
        score = if player.code == pid and should_double, do: score * 2, else: score
        %{player | scores: [score | player.scores]}
      end)

    %Game{game | players: new_players}
  end

  defp set_finished_state(%Game{players: players} = game) do
    max_score = players |> Enum.map(&Enum.sum(&1.scores)) |> Enum.sort() |> List.last()
    next_state = if max_score >= 100, do: :game_finished, else: :round_finished
    %Game{game | state: next_state, out_player: nil}
  end

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
    |> elem(1)
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
