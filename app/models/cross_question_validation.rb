class CrossQuestionValidation < ActiveRecord::Base
  VALID_RULES =
      %w(comparison
         date_implies_constant
         const_implies_const
         const_implies_set
         set_implies_const
         set_implies_set
         blank_unless_const
         blank_unless_set
         blank_unless_days_const
         multi_rule_any_pass
         multi_rule_if_then
         multi_hours_date_to_date
         multi_compare_datetime_quad
         present_implies_present
         const_implies_present
         set_implies_present
         const_implies_one_of_const
         self_comparison
         special_dual_comparison
         special_o2_a
         special_dob)

  RULES_WITH_NO_RELATED = 'special_dob'

  RULES_THAT_APPLY_EVEN_WHEN_ANSWER_NIL = %w(special_dual_comparison)
  RULES_THAT_APPLY_EVEN_WHEN_RELATED_ANSWER_NIL = %w(present_implies_present const_implies_present set_implies_present special_dual_comparison)

  SAFE_OPERATORS = %w(== <= >= < > !=)
  ALLOWED_SET_OPERATORS = %w(included excluded range between)

  belongs_to :question
  belongs_to :related_question, class_name: 'Question'

  validates_inclusion_of :rule, in: VALID_RULES
  validates_inclusion_of :operator, in: SAFE_OPERATORS, allow_blank: true

  validates_presence_of :question_id
  validate :one_of_related_or_list_or_labels
  validates_presence_of :rule
  validates_presence_of :error_message, :if => :primary?
  validates_inclusion_of :primary, in: [true, false]

  serialize :related_rule_ids, Array
  serialize :related_question_ids, Array
  serialize :set, Array
  serialize :conditional_set, Array

  def one_of_related_or_list_or_labels
    return if RULES_WITH_NO_RELATED.include?(rule)
    unless [related_question_id, related_question_ids, related_rule_ids].count(&:present?) == 1
      errors[:base] << "invalid cqv - only one of related question, list of questions or list of rules - " +
          "#{related_question_id.inspect},#{related_question_ids.inspect},#{related_rule_ids.inspect}"
    end
  end

  def self.check(answer)
    cqvs = answer.question.cross_question_validations
    warnings = cqvs.map do |cqv|
      cqv.check answer
    end
    warnings.compact
  end

  def check(answer, running_as_secondary = false)
    checker_params = {operator: operator, constant: constant,
                      set_operator: set_operator, set: set,
                      conditional_operator: conditional_operator, conditional_constant: conditional_constant,
                      conditional_set_operator: conditional_set_operator, conditional_set: conditional_set,
                      related_rule_ids: related_rule_ids, related_question_ids: related_question_ids}

    # we have to filter the answers on the response rather than using find, as we want to check through as-yet unsaved answers as part of batch processing
    related_answer = answer.response.get_answer_to(related_question.id) if related_question

    # if not a primary rule, nil
    # if we dont have a proper answer, nil
    # if we only have one related question, if that doesn't have a proper answer: nil

    return nil unless self.primary? || running_as_secondary

    # don't bother checking if the question is unanswered or has an invalid answer
    if !RULES_THAT_APPLY_EVEN_WHEN_RELATED_ANSWER_NIL.include?(rule)
      return nil if answer.nil? or answer.raw_answer
    end

    # most rules are not run unless the related question has been answered, so unless this is a special rule that runs
    # regardless, first check if a related question is relevant, then check if its answered
    if !RULES_THAT_APPLY_EVEN_WHEN_RELATED_ANSWER_NIL.include?(rule)
      return nil if related_question.present? && (related_answer.nil? or related_answer.raw_answer)
    end

    # Auto-generate an error message if secondary rules don't have one:
    sanitised_error = error_message.present? ? error_message : "Failure in #{rule}"

    # now actually execute the rule
    sanitised_error unless rule_checkers[rule].call answer, related_answer, checker_params
  end

  private

  cattr_accessor(:rule_checkers) { {} }


  def self.is_operator_safe?(operator)
    SAFE_OPERATORS.include? operator
  end

  def self.is_set_operator_valid?(set_operator)
    ALLOWED_SET_OPERATORS.include? set_operator
  end

  def self.register_checker(rule, block)
    # Call register_checker with the rule 'code' of your check.
    # Supply a block that takes the answer and related_answer
    # and returns whether true if the answer meets the rule's criteria
    # The supplied block can assume that no garbage data is stored
    # i.e. that raw_answer is not populated for either answer or related_answer
    rule_checkers[rule] = block
  end


  def self.set_meets_condition?(set, set_operator, value)
    return false unless set.is_a?(Array) && value.present?
    return false unless is_set_operator_valid?(set_operator)

    case set_operator
      when 'included'
        return set.include?(value)
      when 'excluded'
        return (!set.include?(value))
      when 'range' # inclusive
        return (value >= set.first && value <= set.last)
      when 'between' #exclusive
        return (value > set.first && value < set.last)
      else
        return false
    end
  end

  def self.const_meets_condition?(lhs, operator, rhs)
    if is_operator_safe? operator
      return lhs.send operator, rhs
    else
      return false
    end
  end

  def self.aggregate_date_time(d, t)
    Time.utc_time(d.year, d.month, d.day, t.hour, t.min)
  end

  def self.sanitise_offset(checker_params)
    checker_params[:constant].blank? ? 0 : checker_params[:constant]
  end

  register_checker 'comparison', lambda { |answer, related_answer, checker_params|
    break true unless related_answer.answer_value.present?
    offset = sanitise_offset(checker_params)
    const_meets_condition?(answer.comparable_answer, checker_params[:operator], related_answer.answer_with_offset(offset))
  }

  register_checker 'date_implies_constant', lambda { |answer, related_answer, checker_params|
    break true unless related_answer.answer_value.is_a?(Date) || related_answer.answer_value.is_a?(DateInputHandler)
    break true unless answer.answer_value.present?
    const_meets_condition?(answer.comparable_answer, checker_params[:operator], checker_params[:constant])
  }

  register_checker 'const_implies_const', lambda { |answer, related_answer, checker_params|
    break true unless answer.answer_value.present? && related_answer.answer_value.present?
    break true unless const_meets_condition?(related_answer.comparable_answer, checker_params[:conditional_operator], checker_params[:conditional_constant])
    const_meets_condition?(answer.comparable_answer, checker_params[:operator], checker_params[:constant])
  }

  register_checker 'const_implies_set', lambda { |answer, related_answer, checker_params|
    break true unless answer.answer_value.present? && related_answer.answer_value.present?
    break true unless const_meets_condition?(related_answer.comparable_answer, checker_params[:conditional_operator], checker_params[:conditional_constant])
    set_meets_condition?(checker_params[:set], checker_params[:set_operator], answer.comparable_answer)
  }

  register_checker 'set_implies_const', lambda { |answer, related_answer, checker_params|
    break true unless answer.answer_value.present? && related_answer.answer_value.present?
    break true unless set_meets_condition?(checker_params[:conditional_set], checker_params[:conditional_set_operator], related_answer.comparable_answer)
    const_meets_condition?(answer.comparable_answer, checker_params[:operator], checker_params[:constant])
  }

  register_checker 'set_implies_set', lambda { |answer, related_answer, checker_params|
    break true unless answer.comparable_answer.present? && related_answer.comparable_answer.present?
    break true unless set_meets_condition?(checker_params[:conditional_set], checker_params[:conditional_set_operator], related_answer.comparable_answer)
    set_meets_condition?(checker_params[:set], checker_params[:set_operator], answer.comparable_answer)
  }

  register_checker 'blank_unless_const', lambda { |answer, related_answer, checker_params|
    break true unless answer.comparable_answer.present?
    break false unless related_answer.comparable_answer.present? # Fails if RHS populated and LHS is blank (hence doesn't meet conditions)

    #we can assume that at this point, we have a value in both, so we just need to see if the lhs rule passes (content in rhs unimportant)
    const_meets_condition?(related_answer.comparable_answer, checker_params[:conditional_operator], checker_params[:conditional_constant])

  }

  register_checker 'blank_unless_set', lambda { |answer, related_answer, checker_params|
    break true unless answer.answer_value.present?
    break false unless related_answer.answer_value.present? # Fails if RHS populated and LHS is blank (hence doesn't meet conditions)

    #we can assume that at this point, we have a value in both, so we just need to see if the lhs rule passes (content in rhs unimportant)
    set_meets_condition?(checker_params[:conditional_set], checker_params[:conditional_set_operator], related_answer.comparable_answer)

  }

  register_checker 'multi_rule_any_pass', lambda { |answer, related_answer, checker_params|
    rules = CrossQuestionValidation.find(checker_params[:related_rule_ids])

    rules.each do |rule|
      err = rule.check(answer, true)
      return true if !err
    end

    false
  }

#this only accepts two rules - the IF rule and the THEN rule
  register_checker 'multi_rule_if_then', lambda { |answer, related_answer, checker_params|

    rule1 = CrossQuestionValidation.find(checker_params[:related_rule_ids].first)
    rule2 = CrossQuestionValidation.find(checker_params[:related_rule_ids].last)

    answer1 = answer.response.get_answer_to(rule1.question.id) if rule1.question
    answer2 = answer.response.get_answer_to(rule2.question.id) if rule2.question

    err1 = rule1.check(answer1, true)
    break true if err1.present?

    err2 = rule2.check(answer2, true)
    err2.blank?

  }

  register_checker 'multi_hours_date_to_date', lambda { |answer, unused_related_answer, checker_params|
    related_ids = checker_params[:related_question_ids]
    date1 = answer.response.get_answer_to(related_ids[0])
    time1 = answer.response.get_answer_to(related_ids[1])
    date2 = answer.response.get_answer_to(related_ids[2])
    time2 = answer.response.get_answer_to(related_ids[3])

    break true if [date1, time1, date2, time2].any? { |related_answer| related_answer.nil? or related_answer.raw_answer }

    offset = sanitise_offset(checker_params)

    datetime1 = aggregate_date_time(date1.answer_value, time1.answer_value)
    datetime2 = aggregate_date_time(date2.answer_value, time2.answer_value)
    hour_difference = (datetime2 - datetime1) / 1.hour

    const_meets_condition?(answer.answer_value, checker_params[:operator], hour_difference + offset)
  }

  register_checker 'multi_compare_datetime_quad', lambda { |answer, unused_related_answer, checker_params|
    related_ids = checker_params[:related_question_ids]
    date1 = answer.response.get_answer_to(related_ids[0])
    time1 = answer.response.get_answer_to(related_ids[1])
    date2 = answer.response.get_answer_to(related_ids[2])
    time2 = answer.response.get_answer_to(related_ids[3])

    break true if [date1, time1, date2, time2].any? { |answer| answer.nil? || answer.raw_answer }

    datetime1 = aggregate_date_time(date1.answer_value, time1.answer_value)
    datetime2 = aggregate_date_time(date2.answer_value, time2.answer_value)
    offset = sanitise_offset(checker_params)

    const_meets_condition?(datetime1, checker_params[:operator], datetime2 + offset)
  }

  register_checker 'blank_unless_days_const', lambda { |answer, unused_related_answer, checker_params|
    related_ids = checker_params[:related_question_ids]
    date1 = answer.response.get_answer_to(related_ids[0])
    date2 = answer.response.get_answer_to(related_ids[1])

    break true if [date1, date2].any? { |related_answer| related_answer.nil? or related_answer.date_answer.nil? }

    day_difference = (date2.answer_value - date1.answer_value).to_i

    const_meets_condition?(day_difference, checker_params[:conditional_operator], checker_params[:conditional_constant])
  }

  register_checker 'present_implies_present', lambda { |answer, related_answer, checker_params|
    related_answer && !related_answer.raw_answer
  }

  register_checker 'const_implies_present', lambda { |answer, related_answer, checker_params|
    break true unless const_meets_condition?(answer.comparable_answer, checker_params[:operator], checker_params[:constant])
    # we know the answer meets the criteria, so now just check if related has been answered
    related_answer && !related_answer.raw_answer
  }

  register_checker 'set_implies_present', lambda { |answer, related_answer, checker_params|
    break true unless set_meets_condition?(checker_params[:set], checker_params[:set_operator], answer.comparable_answer)
    # we know the answer meets the criteria, so now just check if related has been answered
    related_answer && !related_answer.raw_answer
  }

  register_checker 'const_implies_one_of_const', lambda { |answer, related_answer, checker_params|
    break true unless const_meets_condition?(answer.comparable_answer, checker_params[:operator], checker_params[:constant])
    # we know the answer meets the criteria, so now check if any of the related ones have the correct value
    results = checker_params[:related_question_ids].collect do |question_id|
      related_answer = answer.response.get_answer_to(question_id)
      if related_answer
        const_meets_condition?(related_answer.comparable_answer, checker_params[:conditional_operator], checker_params[:conditional_constant])
      else
        false
      end
    end
    results.include?(true)
  }

# special rules

  register_checker 'special_dual_comparison', lambda { |answer, related_answer, checker_params|
    first = answer.comparable_answer.blank? ? false : const_meets_condition?(answer.comparable_answer,
                                                                             checker_params[:operator],
                                                                             checker_params[:constant])
    second = related_answer.comparable_answer.blank? ? false : const_meets_condition?(related_answer.comparable_answer,
                                                                                      checker_params[:conditional_operator],
                                                                                      checker_params[:conditional_constant])
    (first || second)
  }

  register_checker 'self_comparison', lambda { |answer, unused_related_answer, checker_params|
    const_meets_condition?(answer.comparable_answer, checker_params[:operator], checker_params[:constant])
  }


  register_checker 'special_o2_a', lambda { |answer, unused_related_answer, checker_params|
#    if is -1 then: Gest+Gestdays + weeks(DOB and the latest date of (LastO2|CeaseCPAPDate|CeaseHiFloDate))) >36 [multi_if_then (comparison,special_o2_a)**]

    related_ids = checker_params[:related_question_ids]

    gest = answer.response.get_answer_to(related_ids[0])
    gest_days = answer.response.get_answer_to(related_ids[1])
    dob = answer.response.get_answer_to(related_ids[2])

    last_o2 = answer.response.get_answer_to(related_ids[3])
    cease_cpap_date = answer.response.get_answer_to(related_ids[4])
    cease_hi_flo_date = answer.response.get_answer_to(related_ids[5])

    break true unless gest.comparable_answer.present? && gest_days.comparable_answer.present? && dob.comparable_answer.present?
    break true unless last_o2.comparable_answer.present? || cease_cpap_date.comparable_answer.present || cease_hi_flo_date.comparable_answer.present?

    dates = [last_o2.comparable_answer, cease_cpap_date.comparable_answer, cease_hi_flo_date.comparable_answer]
    dates.sort!
    max_elapsed = dates.last - dob.comparable_answer

    #The actual test (gest in in weeks)
    gest.comparable_answer.weeks + gest_days.comparable_answer.days + max_elapsed.to_i.days > 36.weeks
  }

  register_checker 'special_dob', lambda { |answer, unused_related_answer, checker_params|
    answer.date_answer.year == answer.response.year_of_registration
  }
end
