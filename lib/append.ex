defmodule Append do

# returns s
def send_append_entries_to_all_but_self(s) do
	List.foldl(s.servers, s, fn serverP, s -> if serverP != s.selfP do send_append_entries(s, serverP) else s end end)
end

def send_append_entries(s, serverP) do
	last_log_index = choose_last_log_index(s, serverP)
	s = State.last_log_index(s, last_log_index)
	s = State.next_index(s, serverP, last_log_index)
	# send serverP state, serverP (follower) will extract the necessary info themselves to perform logic
	send serverP, { :APPEND_REQ, s }
	Server.start_rpc_timeout_for_server(s, serverP) # restart rpc_timeout again
end

# returns lower last log index based on lower next_index of serverP or current log length
def choose_last_log_index(s, serverP) do
	n_index_serverP = State.get_next_index(s, serverP)
	log_length = State.get_log_length(s)
	if n_index_serverP < log_length do n_index_serverP else log_length end
end

def process_append_entries_request(own_s, other_s) do
	# logic is in 1 based indexing, need to convert to 0 based indexing when accesing lists
	if State.get_log_length(other_s) != 0 do
		term = other_s.curr_term
		prev_index = other_s.last_log_index - 1
		prev_entry = Enum.at(other_s.log, State.get_next_index(other_s, own_s.selfP) - 1)
		prev_term = prev_entry.term
		entries = for i <- [other_s.last_log_index .. State.get_log_length(other_s)], do: Enum.at(other_s.log, i)
		commit_index = other_s.commit_index

		success = prev_index == 0 or (prev_index <= length(own_s.log) and Enum.at(own_s.log, prev_index - 1).term == prev_term)

		{ index, own_s } = if success do storeEntries(own_s, prev_index, entries, commit_index) else { 0, own_s } end

		# other_s.curr_term is used to since the only reason it will process is because of successful term match
		send other_s.selfP, { :APPEND_REP, other_s.curr_term, success, index }
		own_s
	else
		own_s
	end
end

# returns index
def storeEntries(s, prev_index, entries, commitIndex) do
	Monitor.log(s, "#Server {s.id} stored entry")
end

# returns { accepted : boolean, state }
def process_heartbeat_request(own_s, other_s) do
	# dont respond to own heartbeats
	if rpc_from_self(own_s, other_s) do
		{ false, own_s }
	else
		# else process request
		if valid_heartbeat_request(own_s, other_s) do
			own_s = State.curr_term(own_s, other_s.curr_term)
			send other_s.selfP, { :HEARTBEAT_REP, true, own_s }
			{ true, own_s }
		else
			Monitor.debug_action(own_s, other_s, 0, "rejected heartbeat from")
			send other_s.selfP, { :HEARTBEAT_REP, false, own_s }
			{ false, own_s }
		end
	end
end

# own current term lower or equal
def valid_heartbeat_request(own_s, other_s) do
	has_lower_term(own_s, other_s)
	or is_same_term_but_self_not_leader(own_s, other_s)
end

def rpc_from_self(own_s, other_s) do
	own_s.id == other_s.id
end

def has_lower_term(own_s, other_s) do
	own_s.curr_term < other_s.curr_term
end

def is_same_term_but_self_not_leader(own_s, other_s) do
	own_s.curr_term == other_s.curr_term and own_s.role != :LEADER
end

end