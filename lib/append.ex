defmodule Append do

# returns { replied : boolean, state }
def process_heartbeat_request(own_s, other_s) do
	if valid_heartbeat_request(own_s, other_s) do
		own_s = State.curr_term(own_s, other_s.curr_term)
		send other_s.selfP, { :HEARTBEAT_REP }
		{ true, own_s }
	else
		{ false, own_s }
	end
end

# own current term lower or equal
def valid_heartbeat_request(own_s, other_s) do
	has_lower_term(own_s, other_s) or is_same_term_but_self_not_leader(own_s, other_s)
end

def has_lower_term(own_s, other_s) do
	own_s.curr_term < other_s.curr_term
end

def is_same_term_but_self_not_leader(own_s, other_s) do
	own_s.curr_term == other_s.curr_term and own_s.role !== :LEADER
end

end