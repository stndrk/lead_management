# frozen_string_literal: true

class CustomerLead < ApplicationRecord
  validates :mobile, presence: true
  validates :loan_uid, uniqueness: true, allow_nil: true

  before_save :upcase_status

  def age
    return if dob.blank?

    age_in_years = Date.today.year - dob.year
    age_in_years -= 1 if Date.today < dob + age_in_years.years
    age_in_years
  end

  private

  def upcase_status
    self.status = status.upcase if status.present?
  end
end
