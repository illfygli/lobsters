#!/usr/bin/env ruby

# ENV["RAILS_ENV"] ||= "production"

APP_PATH = File.expand_path("../../config/application", __FILE__)
require File.expand_path("../../config/boot", __FILE__)
require APP_PATH
Rails.application.require_environment!

# accept all follow requests
follow_requests = Mastodon.get_follow_requests
follow_requests.each do |id|
  Mastodon.accept_follow_request(id)
end

# reconcile public list with our linked accounts
acct_to_id = Mastodon.get_list_accounts
their_users = acct_to_id.keys.to_set
our_users = Set.new(
  User.active.where("settings LIKE '%mastodon_username:%'")
    .select { |u| u.mastodon_username.present? }
    .map { |u| "#{u.mastodon_username}@#{u.mastodon_instance}" }
)

# puts "their_users", their_users
# puts "our_users", our_users
to_remove = their_users - our_users
to_add = our_users - their_users

# Mastodon requires following a user to add them to a list

if to_remove.any?
  Mastodon.remove_list_accounts(to_remove.map { |a| acct_to_id[a] })
  to_remove.each do |a|
    Mastodon.unfollow_account(acct_to_id[a])
  end
end

if to_add.any?
  to_add.each do |a|
    id = Mastodon.get_account_id(a)
    Mastodon.follow_account(id)
  end
  Mastodon.add_list_accounts(to_add)
end
