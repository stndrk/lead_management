# frozen_string_literal: true

class CustomersController < HelperController
  before_action :require_login

  def some_action
    @current_user = current_user
  end

  def fetch
    @customers = Kaminari.paginate_array(CustomerLead.select(:id, :first_name, :last_name, :status, :mobile, :offered_amount, :created_at, :rejection_reason).to_a).page(params[:page]).per(10)
    render :fetch
  end

  def filter
    filter = params[:filter]
    @customers = CustomerLead.all

    @customers = @customers.where("mobile = ? OR loan_uid = ?", filter, filter).select(:id, :first_name, :last_name, :status, :mobile, :offered_amount, :created_at, :rejection_reason) if filter.present?
    @customers = Kaminari.paginate_array(@customers).page(params[:page]).per(10)
    render json: @customers
  end

  def update
    customer_lead = CustomerLead.find(params[:id])
    if customer_lead.update(customer_lead_params)
      render json: customer_lead, status: :ok
    else
      render json: customer_lead.errors, status: :unprocessable_entity
    end
  end

  private

  def require_login
    return if current_user

    flash[:error] = "You must be logged in to access this page."
    redirect_to "/user_login"
  end

  def customer_lead_params
    params.require(:customer_lead).permit(:first_name, :last_name, :dob, :pan_number, :mobile, :email, :guardain_name,
                                          :lender_code, :status, :rejection_reason, :offered_at, :accepted_at, :alternate_mobile_number,
                                          :disbursed_at, :kyc_on_hold_at, :monthly_income, :joined_on, :product_code, :type_of_loan,
                                          :customer_code, :partner_code, :loan_uid, :disburse_amount, :offered_amount, :journey_link, :bureau_score,
                                          :product_category, :gender, :other_details, :home_address, :home_pincode, :business_address, :business_pincode)
          .merge(latitude: params[:latitude], longitude: params[:longitude], accuracy: params[:accuracy], occupation_category: params[:occupation_category])
  end
end
