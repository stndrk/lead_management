# frozen_string_literal: true

class UpdateLoanStatusService
  attr_reader :customer_lead_id, :error_code, :result

  def initialize(customer_lead_id)
    @customer_lead_id = customer_lead_id
    @error_code = "INVALID"
  end

  def prequalification
    endpoint = full_url("pre_qualification/#{customer_lead_id}")
    serv = get(endpoint, headers(endpoint), nil)
    result = if serv["response"] && serv["response"]["prequalification"]
               check_offer(serv["response"])
             else
               [false, "Prequalification not Found"]
             end
    result
  end

  def fetch_loan_details
    endpoint = full_url("loan/profile/#{customer_lead_id}")
    serv = get(endpoint, headers(endpoint), nil)
    result = if serv["response"] && serv["response"]["loan_status"]
               update(serv["response"])
             else
               [false, "Loan not Found"]
             end
    result
  end

  def create_signature(full_url)
    api_salt = ENV["ARTH_API_SALT"]
    api_key = ENV["ARTH_API_KEY"]
    signature = [api_salt, api_key, full_url].join("|")
    OpenSSL::HMAC.hexdigest("SHA256", api_key, signature)
  end

  def full_url(path)
    timestamp = Time.zone.now.to_i
    "#{ENV['ARTH_URL']}/#{path}?sent_at=#{timestamp}"
  end

  def headers(full_url)
    {
      "Content-Type" => "application/json",
      "x-api-key"    => ENV["ARTH_API_KEY"],
      "X-Signature"  => create_signature(full_url)
    }
  end

  def get(endpoint, headers, _payload)
    uri = URI(base_url + endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri, headers)
    response = http.request(request)
    JSON.parse(response.body)
  end

  def soa
    @soa ||= SoaV2.new
  end

  def base_url
    ENV["ADL_PARTNER_URL"]
  end

  def request_ref
    @request_ref ||= SecureRandom.uuid
  end

  def update(response) # rubocop:disable Metrics/MethodLength
    customer_lead = CustomerLead.find(customer_lead_id)
    attributes = {
      lender_code:      response["lender_code"],
      status:           response["status"],
      rejection_reason: response["private_reason"],
      accepted_at:      response["accepted_at"],
      kyc_on_hold_at:   response["kyc_on_hold_at"],
      product_code:     response["product_code"],
      customer_code:    response["customer_code"],
      partner_code:     response["partner_code"],
      loan_uid:         response["loan_uid"],
      disburse_amount:  response["amount_disbursed"],
      other_details:    {humanized_reason => response["humanized_reason"],
                         requested_at     => response["requested_at"],
                         rejected_at      => response["rejected_at"],
                         approved_at      => response["approved_at"]},
      product_category: response["tenure"],
      disbursed_at:     response["disbursed_at"]
    }

    if customer_lead.update(attributes.compact)
      [@customer_lead_id, true]
    else
      [@customer_lead_id, false]
    end
  end

  def check_offer(response)
    customer_lead = CustomerLead.find(customer_lead_id)
    attributes = {
      status:         response["status"],
      offered_at:     response["offered_at"],
      joined_on:      response["joined_on"],
      product_code:   response["product_code"],
      customer_code:  response["customer_code"],
      offered_amount: response["offered_amount"],
      journey_link:   response["journey_link"]
    }

    if customer_lead.update(attributes.compact)
      [@customer_lead_id, true]
    else
      [@customer_lead_id, false]
    end
  end
end
