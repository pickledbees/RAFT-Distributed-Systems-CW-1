defmodule Vote do

# returns { voted : boolean , state }
def process_vote_request(own_s, other_s) do

	# check for vote validity
	if vote_request_invalid(own_s, other_s) do
		{ false, own_s }
	else
		# prep for new election term if it occurs
		own_s = if own_s.curr_term < other_s.curr_term do
					own_s = State.curr_term(own_s, other_s.curr_term)
					own_s = State.voted_for(own_s, nil)
				else
					own_s
				end

		own_s = State.voted_for(own_s, other_s.id)

		Monitor.debug(own_s, 0, "#{Atom.to_string(own_s.role)} #{own_s.id} voted for Candidate #{other_s.id}")

		send other_s.selfP, { :VOTE_REP, own_s }
		{ true, own_s }
	end
end

defp vote_request_invalid(own_s, other_s) do
	is_requesting_from_outdated_election_term(own_s, other_s)
	or already_voted_this_term(own_s, other_s)
	or has_higher_last_log_term(own_s, other_s)
	or has_equal_last_log_term_and_higher_last_log_index(own_s, other_s)
end

defp is_requesting_from_outdated_election_term(own_s, other_s) do
	own_s.curr_term > other_s.curr_term
end

defp already_voted_this_term(own_s, other_s) do
	own_s.curr_term == other_s.curr_term and own_s.voted_for != nil
end

defp has_higher_last_log_term(own_s, other_s) do
	# implement later
	false
end

defp has_equal_last_log_term_and_higher_last_log_index(own_s, other_s) do
	# implement later
	false
end

end