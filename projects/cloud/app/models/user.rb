# frozen_string_literal: true

class User < ApplicationRecord
  module Error
    Base = Class.new(StandardError)
    CantObtainAccountName = Class.new(Base)
  end

  ACCOUNT_SUFFIX_LIMIT = 5

  rolify

  # Callbacks
  before_validation :create_account, if: -> (user) { user.account.nil? }

  # Devise
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable,
    :lockable, :timeoutable, :trackable,
    :omniauthable,
    omniauth_providers: [:github, :gitlab]

  # Associations
  has_one :account, as: :owner, inverse_of: :owner, dependent: :destroy, required: true, autosave: true
  belongs_to :last_visited_project, class_name: "Project", optional: true

  def avatar_url
    hash = Digest::MD5.hexdigest(email.downcase)
    "https://www.gravatar.com/avatar/#{hash}"
  end

  def accounts
    UserAccountsFetchService.call(user: self)
  end

  private
    def create_account
      self.account = Account.new(name: account_name)
    end

    def account_name(suffix: nil)
      name = email.split("@").first
      name = suffix.nil? ? name : name + suffix.to_s
      return name if Account.where(name: name).count == 0
      suffix = suffix.nil? ? 1 : suffix + 1
      raise Error::CantObtainAccountName if suffix == ACCOUNT_SUFFIX_LIMIT
      account_name(suffix: suffix)
    end
end
