defmodule Append do

# returns { accepted : boolean, state }
def process_heartbeat_request(own_s, other_s) do
	# dont respond to own heartbeats
	if rpc_from_self(own_s, other_s) do
		{ false, own_s }
	else
		# else process request
		if valid_heartbeat_request(own_s, other_s) do
			own_s = State.curr_term(own_s, other_s.curr_term)
			send other_s.selfP, { :APPEND_REP, { :HEARTBEAT_REP, true } , own_s }
			{ true, own_s }
		else
			Monitor.debug_action(own_s, other_s, 0, "rejected heartbeat from")
			send other_s.selfP, { :APPEND_REP, { :HEARTBEAT_REP, false } , own_s }
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