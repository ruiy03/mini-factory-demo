# frozen_string_literal: true

require "date"

RSpec.describe MiniFactoryDemo::User do
  describe "#initialize" do
    it "stores all four attributes" do
      user = described_class.new(
        first_name: "Alice",
        last_name: "Smith",
        email: "alice@example.com",
        birthdate: Date.new(2000, 1, 1)
      )
      expect(user.first_name).to eq("Alice")
      expect(user.last_name).to eq("Smith")
      expect(user.email).to eq("alice@example.com")
      expect(user.birthdate).to eq(Date.new(2000, 1, 1))
    end

    it "defaults all attributes to nil" do
      user = described_class.new
      expect(user.first_name).to be_nil
      expect(user.last_name).to be_nil
      expect(user.email).to be_nil
      expect(user.birthdate).to be_nil
    end
  end

  describe "#full_name (spec 1)" do
    it "joins first and last name with a space" do
      user = described_class.new(first_name: "Alice", last_name: "Smith")
      expect(user.full_name).to eq("Alice Smith")
    end

    it "returns first name only when last_name is nil" do
      user = described_class.new(first_name: "Alice")
      expect(user.full_name).to eq("Alice")
    end

    it "returns last name only when first_name is nil" do
      user = described_class.new(last_name: "Smith")
      expect(user.full_name).to eq("Smith")
    end

    it "returns empty string when both are nil" do
      user = described_class.new
      expect(user.full_name).to eq("")
    end

    it "trims ASCII whitespace from each name" do
      user = described_class.new(first_name: "  Alice  ", last_name: "Smith")
      expect(user.full_name).to eq("Alice Smith")
    end
  end

  describe "#email_address (spec 2)" do
    it "returns the email unchanged when already lowercase and trimmed" do
      user = described_class.new(email: "alice@example.com")
      expect(user.email_address).to eq("alice@example.com")
    end

    it "lowercases mixed-case emails" do
      user = described_class.new(email: "Alice@Example.COM")
      expect(user.email_address).to eq("alice@example.com")
    end

    it "trims surrounding whitespace" do
      user = described_class.new(email: "  alice@example.com  ")
      expect(user.email_address).to eq("alice@example.com")
    end

    it "returns nil when email is nil" do
      user = described_class.new(email: nil)
      expect(user.email_address).to be_nil
    end
  end

  describe "#age_in_years (spec 3)" do
    let(:reference_today) { Date.new(2026, 5, 10) }

    it "returns full age when the birthday already passed this year" do
      user = described_class.new(birthdate: Date.new(2000, 1, 1))
      expect(user.age_in_years(today: reference_today)).to eq(26)
    end

    it "decrements age when the birthday hasn't occurred yet this year" do
      user = described_class.new(birthdate: Date.new(2000, 6, 1))
      expect(user.age_in_years(today: reference_today)).to eq(25)
    end

    it "returns full age when today is the birthday" do
      user = described_class.new(birthdate: Date.new(2000, 5, 10))
      expect(user.age_in_years(today: reference_today)).to eq(26)
    end

    it "returns nil when birthdate is nil" do
      user = described_class.new(birthdate: nil)
      expect(user.age_in_years(today: reference_today)).to be_nil
    end
  end
end
