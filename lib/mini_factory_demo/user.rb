# frozen_string_literal: true

require "date"

module MiniFactoryDemo
  # User holds the demo target attributes for the mini Software Factory.
  # The PRD in `.claude/intent.md` works through a 3-spec backlog one at a time:
  # `#full_name` (done), `#email_address` (TODO), and `#age_in_years` (TODO).
  class User
    attr_accessor :first_name, :last_name, :email, :birthdate

    def initialize(first_name: nil, last_name: nil, email: nil, birthdate: nil)
      @first_name = first_name
      @last_name = last_name
      @email = email
      @birthdate = birthdate
    end

    # Spec 1 (done): join first_name and last_name, ASCII-trim each part,
    # drop empties, and return a single-space-separated string.
    def full_name
      [first_name, last_name].compact.map(&:strip).reject(&:empty?).join(" ")
    end

    # TODO: implement email_address for spec 2 — return `email` lowercased
    # and ASCII-trimmed, or nil when email is nil. See PRD scenarios 6-9.

    # TODO: implement age_in_years(today: Date.today) for spec 3 — return an
    # integer year age, decremented if the birthday hasn't occurred yet this
    # year. Return nil when birthdate is nil. See PRD scenarios 10-13.
  end
end
