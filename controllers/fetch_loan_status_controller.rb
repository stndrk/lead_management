# frozen_string_literal: true

class FetchLoanStatusController < HelperController
  before_action :require_login
  skip_before_action :verify_authenticity_token, only: :sync_loan_status

  def sync_loan_status
    customer_lead_ids = params[:ids]
    success_ids = []
    failed_ids = []

    customer_lead_ids.each do |customer_lead_id|
      serv = UpdateLoanStatusService.new(customer_lead_id)
      if serv.fetch_loan_details
        success_ids << customer_lead_id
      else
        failed_ids << customer_lead_id
      end
    end

    render json: {success_ids: success_ids, failed_ids: failed_ids}, status: :ok
  end

  def sync_loan_webhook
    if update(webhook_params)
      render json: {msg: "data updated successfully"}, status: 200
    else
      render json: {msg: "data not found"}, status: 400
    end
  end

  def fetch_prequalification
    customer_lead_ids = params[:ids]
    success_ids = []
    failed_ids = []

    customer_lead_ids.each do |customer_lead_id|
      serv = UpdateLoanStatusService.new(customer_lead_id)
      if serv.prequalification
        success_ids << customer_lead_id
      else
        failed_ids << customer_lead_id
      end
    end

    render json: {success_ids: success_ids, failed_ids: failed_ids}, status: :ok
  end

  private

  def webhook_params
    params.permit(:product_code, :customer_code, :partner_code, :loan_uid, :status, :rejection_reason, :offered_at, :created_at,
                  :updated_at, :accepted_at, :disbursed_at, :kyc_on_hold_at, :amount_disbursed)
  end

  def update(response) # rubocop:disable Metrics/MethodLength
    customer_lead = CustomerLead.find_by(customer_code: response[:customer_code])
    return false unless customer_lead

    attributes = {
      status:           response[:status],
      rejection_reason: response[:private_reason],
      accepted_at:      response[:accepted_at],
      kyc_on_hold_at:   response[:kyc_on_hold_at],
      product_code:     response[:product_code],
      customer_code:    response[:customer_code],
      partner_code:     response[:partner_code],
      loan_uid:         response[:loan_uid],
      disburse_amount:  response[:amount_disbursed],
      other_details:    {
        humanized_reason: response[:humanized_reason],
        requested_at:     response[:requested_at],
        rejected_at:      response[:rejected_at],
        approved_at:      response[:approved_at]
      },
      product_category: response[:tenure],
      disbursed_at:     response[:disbursed_at]
    }

    customer_lead.update(attributes.compact)
  end
end
