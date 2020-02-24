
# distributed algorithms, n.dulay, 4 feb 2020
# coursework, raft consensus, v1

defmodule State do

# *** short-names: s for 'server', m for 'message'

def initialise(config, server_id, servers, databaseP) do
  %{
    config:       config,     # system configuration parameters (from DAC)
    selfP:        self(),     # server's process id
    id:	          server_id,  # server's id (simple int)
    servers:      servers,    # list of process id's of servers
    databaseP:    databaseP,  # process id of local database
    majority:     div(length(servers)+1, 2),
    votes:        0,          # count of votes incl. self

    # -- various process id's - omitted

    # -- raft persistent data
    # -- update on stable storage before replying to requests
    curr_term:	  0,
    voted_for:	  nil,
    log:          ["blank"],  

    # -- raft non-persistent data
    dummy_heartbeat_ref: nil,    # for dummy heartbeat
    rpc_timer_refs: Map.new,
    role:	  :FOLLOWER,
    commit_index: 0,
    last_applied: 0,
    next_index:   Map.new,   
    match_index:  Map.new,

    last_log_index: nil,
 
    # add additional state variables of interest
  }
end # initialise

def new_log_entry(s, cmd) do
    %{
        term: s.curr_term,
        cmd: cmd,
    }
end

def append_cmd_to_log(s, cmd), do: Map.put(s, :log, s.log ++ [new_log_entry(s, cmd)])
def get_log_entry(s, index), do: Enum.at(s.log, index)
def get_log_length(s), do: length(s.log) - 1

# setters for raft state
def votes(s, v),          do: Map.put(s, :votes, v)
def dummy_heartbeat_ref(s, ref), do: Map.put(s, :dummy_heartbeat_ref, ref)
def rpc_timer_ref(s, pid, ref), do: Map.put(s, :rpc_timer_refs, Map.put(s.rpc_timer_refs, pid, ref))
def role(s, v),           do: Map.put(s, :role, v)
def curr_term(s, v),      do: Map.put(s, :curr_term, v)
def voted_for(s, v),      do: Map.put(s, :voted_for, v)
def commit_index(s, v),   do: Map.put(s, :commit_index, v)
def last_applied(s, v),   do: Map.put(s, :last_applied, v)
def next_index(s, v),     do: Map.put(s, :next_index, v)      # sets new next_index map
def next_index(s, pid, v), do: Map.put(s, :next_index,
                                  Map.put(s.next_index, pid, v))
def match_index(s, v),    do: Map.put(s, :match_index, v)     # sets new  match_index map
def match_index(s, id, v), do: Map.put(s, :match_index,
                                  Map.put(s.match_index, id, v))

def last_log_index(s, index), do: Map.put(s, :last_log_index, index)

# getters to self define since to allow for flexibility of default values
def get_rpc_timer_ref(s, pid), do: Map.get(s.rpc_timer_refs, pid, nil)
def get_next_index(s, pid), do: Map.get(s.next_index, pid, 1)
def get_match_index(s, pid), do: Map.get(s.match_index, pid, 0)

# add additional setters 

end # State
