
# distributed algorithms, n.dulay, 4 feb 2020
# coursework, raft consensus, v1

# define Component to be Server/Client/Database

# KEY THING TO NOTE:
# - Concept of state:
#   - used by Monitor to extract relavant info to print
#   - Monitor will need to know how the state of each Component looks like to extract relevant info
#   - should always contain 'config' attribute for monitor to refer to current monitorP and other relevant process info

defmodule Monitor do

# s refers to 'state'
# MUST have config property containing the config Map
# used by other processes to send messages to the current running monitor
def notify(component, message) do send component.config.monitorP, message end

# default debugs
def debug(component, string) do 
 if component.config.debug_level == 0 do IO.puts "#{string}" end
end # debug

# to selectivly choose at what depth of debuggin required
def debug(component, level, string) do 
 if level >= component.config.debug_level do IO.puts "#{string}" end
end # debug

# used by state formatter
def pad(key), do: String.pad_trailing("#{key}", 10)

# print formatted state of server
def printServerState(serverS, level, string) do 
 if level >= serverS.config.debug_level do 
   state_out = for {key, value} <- serverS, into: "" do "\n  #{pad(key)}\t #{inspect value}" end
   IO.puts "\nserver #{serverS.id} #{serverS.role}: #{inspect serverS.selfP} #{string} state = #{state_out}"
 end # if
end # state

# stops all elixir processes, printing out the desired string just before halt
def halt(string) do
  IO.puts "monitor: #{string}"
  System.stop
end # halt

def halt(s, string) do
  IO.puts "server #{s.id} #{string}"
  System.stop
end # halt

def letter(s, letter) do 
  if s.config.debug_level == 3, do: IO.write(letter)
end # letter

def start(config) do
  state = %{
    config:             config,
    clock:              0,
    requests:           Map.new,
    updates:            Map.new,
    moves:              Map.new,
    # rest omitted
  }
  Process.send_after(self(), { :PRINT }, state.config.print_after)
  Monitor.next(state)
end # start

def clock(state, v), do: Map.put(state, :clock, v)

# i is server_number
# v is number or requests to that server
# updater for monitors' state
def requests(state, i, v), do: 
    Map.put(state, :requests, Map.put(state.requests, i, v))

# similar to requests
def updates(state, i, v), do: 
    Map.put(state, :updates,  Map.put(state.updates, i, v))

def moves(state, v), do: Map.put(state, :moves, v)

def next(state) do
  # messages are sent by calling the Monitor.notify() method
  receive do
  { :DB_MOVE, db, seqnum, command} ->
    { :move, amount, from, to } = command

    done = Map.get(state.updates, db, 0)

    if seqnum != done + 1, do: 
       Monitor.halt "  ** error db #{db}: seq #{seqnum} expecting #{done+1}"

    moves =
      case Map.get(state.moves, seqnum) do
      nil ->
        # IO.puts "db #{db} seq #{seqnum} = #{done+1}"
        Map.put state.moves, seqnum, %{ amount: amount, from: from, to: to }

      t -> # already logged - check command
        if amount != t.amount or from != t.from or to != t.to, do:
	  Monitor.halt " ** error db #{db}.#{done} [#{amount},#{from},#{to}] " <>
            "= log #{done}/#{map_size(state.moves)} [#{t.amount},#{t.from},#{t.to}]"
        state.moves
      end # case

    state = Monitor.moves(state, moves)
    state = Monitor.updates(state, db, seqnum)
    Monitor.next(state)

  { :CLIENT_REQUEST, server_num } ->  # client requests seen by leaders
    state = Monitor.requests(state, server_num, state.requests + 1)
    Monitor.next(state)

  # message to send to monitor to do a print of state
  { :PRINT } ->
    clock  = state.clock + state.config.print_after
    state  = Monitor.clock(state, clock)
    sorted = state.updates  |> Map.to_list |> List.keysort(0)
    IO.puts "time = #{clock}      db updates done = #{inspect sorted}"
    sorted = state.requests |> Map.to_list |> List.keysort(0)
    IO.puts "time = #{clock} client requests seen = #{inspect sorted}"

    if state.config.debug_level >= 0 do  # always
      min_done   = state.updates  |> Map.values |> Enum.min(fn -> 0 end)
      n_requests = state.requests |> Map.values |> Enum.sum
      IO.puts "time = #{clock}           total seen = #{n_requests} max lag = #{n_requests-min_done}"
    end

    IO.puts ""
    Process.send_after(self(), { :PRINT }, state.config.print_after)
    Monitor.next(state)

  # print on leader election
  { :LEADER_ELECTED, s } ->
    IO.puts "Event: SERVER #{s.id} IS LEADER"
    Monitor.next(state)

  unexpected ->
    Monitor.halt "monitor: unexpected message #{inspect unexpected}"
  end # receive
end # next

end # Monitor

