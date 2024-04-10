# frozen_string_literal: true

class Faircent
  def register_lead(mobile)
    endpoint = "https://api.faircent.com/v1/api/aggregrator/register/user"
    user = CustomerLead.find_by(mobile: mobile)
    return user.update(faircent_response: "age norms not match", faircent_status: "rejected") unless user && user.monthly_income >= 25_000 && user.age >= 23 && user.age <= 58

    payload = create_payload(user)
    response = post(endpoint, payload, headers)
    status = if response["result"].present?
               response["result"]["status"]
             else
               "rejected"
             end
    user.update(faircent_response: response, faircent_status: status)
  end

  def create_payload(user)
    {
      fname:             fname(user),
      lname:             lname(user),
      dob:               dob(user),
      pan:               user.pan_number,
      mobile:            user.mobile,
      mail:              user.email,
      pin:               user.home_pincode,
      state:             user.home_state,
      city:              user.home_city,
      address:           user.home_address,
      gender:            user.gender.strip[0].capitalize,
      employment_status: "Self Employed",
      loan_purpose:      "90156671",
      loan_amount:       loan_amount(user.monthly_income),
      monthly_income:    user.monthly_income
    }
  end

  def loan_amount(salary)
    case salary
    when 25_000..40_000
      50_000
    when 40_001..50_000
      75_000
    when 50_001..75_000
      100_000
    when 75_001..100_000
      125_000
    when 100_001..125_000
      150_000
    when 125_001..150_000
      200_000
    when 150_001..200_000
      500_000
    else
      0.0
    end
  end

  def fname(user)
    parts = user.first_name.split(" ")
    parts.length >= 2 ? parts[0] : user.first_name
  end

  def lname(user)
    parts = user.last_name.split(" ")
    parts.length > 1 ? user.last_name : user.first_name
  end

  def dob(user)
    user.dob.strftime("%Y-%m-%d")
  end

  def headers
    {
      "x-application-id":   "5b3ec5c6f0a779bb18df8a8ac054d759",
      "x-application-name": "HAPPYLOAN",
      "Content-Type":       "application/json"
    }
  end

  def post(endpoint, data, headers)
    uri = URI(endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path, headers)
    request.body = data.to_json
    response = http.request(request)
    JSON.parse(response.read_body)
  end
end
