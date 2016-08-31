module Payment
  extend ActiveSupport::Concern

  included do
    include Stripe::Callbacks

    after_charge_failed! do |data|
      user = Subscriber.find_by_customer_token(data.customer)
      user.update(payment_status: 'Failed')
      Message.send_payment_failure(user)
    end

    after_charge_succeeded! do |data|
      user = Subscriber.find_by_customer_token(data.customer)
      user.update(payment_status: 'Active')
    end

    def save_with_payment
      if valid?
        customer = Stripe::Customer.create(description: type, email: email, plan: 'monthly', card: card_token)
        self.customer_token = customer.id
        self.payment_status = 'Processing'
        save!
      end
    rescue Stripe::InvalidRequestError => e
      logger.error "Stripe error while creating subscriber #{self.id}: #{e.message}"
      errors.add :base, 'There was a problem with your credit card.'
      false
    end
  end
end