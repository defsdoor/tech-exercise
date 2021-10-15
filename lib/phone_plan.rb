require 'forwardable'

class PhonePlan
  extend Forwardable

  def_delegators :@flexible_plan, :cost
  def_delegators :@flexible_plan, :price
  def_delegators :@flexible_plan, :per_phone_matrix
  def_delegators :@flexible_plan, :discount_matrix

  attr_accessor :type

  def initialize(number_of_phones:, price:, type:, per_phone_matrix: nil, discount_matrix: nil)
    @type = type
    @flexible_plan = case type
                     when 'family'
                       # Hardwired plans mapped to flexible ones
                       # Family plan - no discounts, additional phones @ £10
                       FlexiblePhonePlan.new(number_of_phones: number_of_phones,
                                             price: price,
                                             per_phone_matrix: { 1 => price, 2 => 10 })
                     when 'business'
                       # Business plan - discount % only
                       FlexiblePhonePlan.new(number_of_phones: number_of_phones,
                                             price: price,
                                             discount_matrix: { 1 => 0.75, 50 => 0.5 })
                     else
                       # Individual and unspecified plans, no discounts, all phones @ price
                       FlexiblePhonePlan.new(number_of_phones: number_of_phones,
                                             price: price)
                     end
  end
end

class FlexiblePhonePlan
  attr_reader :number_of_phones, :price, :per_phone_matrix, :discount_matrix

  # At this stage the matrices should probably be arrays of struct (at least) 
  # but we aren't writing a billing system - today ;)
  def initialize(number_of_phones:, price:, per_phone_matrix: { 1 => price }, discount_matrix: {})
    @number_of_phones = number_of_phones
    @price = price
    @per_phone_matrix = per_phone_matrix || { 1 => @price }
    @discount_matrix = discount_matrix || { 1 => 1 }
  end

  def cost
    total_per_phone_cost * discount_break_point
  end

  private

  def discount_break_point
    @discount_matrix.sort.to_h.filter_map do |breakpoint, discount|
      discount if @number_of_phones >= breakpoint
    end.last || 1
  end

  def per_phone_costs
    phone_cnt = @number_of_phones
    last_breakpoint = nil
    cost_spread = @per_phone_matrix.sort.filter_map do |breakpoint, price|
      if phone_cnt >= breakpoint || !last_breakpoint
        phone_cnt -= breakpoint
        last_breakpoint = breakpoint
        [price, breakpoint]
      end
    end
    cost_spread.last[1] += phone_cnt if phone_cnt.positive?
    cost_spread
  end

  def total_per_phone_cost
    per_phone_costs.inject(0) do |result, stage|
      result += stage[0] * stage[1]
    end
  end
end
