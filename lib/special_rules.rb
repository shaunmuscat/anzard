class SpecialRules
  GEST_CODE = 'Gest'
  GEST_DAYS_CODE = 'GestDays'
  WGHT_CODE = 'Wght'
  DOB_CODE = 'DOB'
  LAST_O2_CODE = 'LastO2'
  LAST_RESP_SUPP_CODE = 'LastRespSupp'
  CEASE_CPAP_DATE_CODE = 'CeaseCPAPDate'
  CEASE_HI_FLO_DATE_CODE = 'CeaseHiFloDate'
  HOME_DATE_CODE = 'HomeDate'

  RULE_CODES_REQUIRING_PARTICULAR_QUESTION_CODES = {
    'special_o2_a' => 'O2_36wk_',
    'special_o2_a_new' => 'O2_36wk_',
    'special_hmeo2' => 'HmeO2',
    'special_hmeo2_new' => 'HmeO2',
    'special_namesurg2' => 'Surg_Desc2',
    'special_namesurg3' => 'Surg_Desc3',
    'special_cool_hours' =>'StartCoolDate',
    'special_immun' => 'DOB',
    'special_date_of_assess' => 'DateOfAssess',
    'special_height' => 'Hght',
    'special_length' => 'Length',
    'special_cochimplt' => 'CochImplt',
    'special_rule22d' => 'N_V_EGTH',
    'special_rule17_a' => 'PR_CLIN',
    'special_rule_gest_iui_date' => 'PR_END_DT',
    'special_rule_gest_et_date' => 'PR_END_DT',
    'special_rule_donor_1' => 'N_S_CLTH',
    'special_rule_don_age' => 'SURR'
  }

  def self.additional_cqv_validation(cqv)
    if cqv.rule and cqv.question
      required_question_code = RULE_CODES_REQUIRING_PARTICULAR_QUESTION_CODES[cqv.rule]
      actual_question_code = cqv.question.code
      if required_question_code and actual_question_code != required_question_code
	cqv.errors[:base] << "#{cqv.rule} requires question code #{required_question_code} but got #{actual_question_code}"
      end
    end
  end

  def self.register_additional_rules
    # put special rules here that aren't part of the generic rule set, that way they can easily be removed or replaced later

    # add to the list of rules with no related question
    CrossQuestionValidation.rules_with_no_related_question += %w(special_dob
                                 special_rop_prem_rop_vegf_1
                                 special_rop_prem_rop_vegf_2
                                 special_rop_prem_rop
                                 special_rop_prem_rop_retmaturity
                                 special_rop_prem_rop_roprx_1
                                 special_rop_prem_rop_roprx_2
                                 special_namesurg2
                                 special_namesurg3
                                 special_immun
                                 special_cool_hours
                                 special_date_of_assess
                                 special_height
                                 special_length
                                 special_cochimplt
                                 special_o2_a
                                 special_o2_a_new
                                 special_hmeo2
                                 special_hmeo2_new
                                 special_same_name_inf
                                 special_pns
                                 special_rule22d
                                 special_rule17_a
                                 special_rule_gest_iui_date
                                 special_rule_gest_et_date
                                 special_rule_donor_1
                                 special_rule_don_age)
    CrossQuestionValidation.register_checker 'special_pns', lambda { |answer, unused_related_answer, unused_checker_params|
      # It should not be an error_flag if PNS==-1 and (Gest<32 or Wght<1500).
      # An error_flag if PNS==-1 and (Gest>=32 and Wght>=1500)
      gest = answer.response.comparable_answer_or_nil_for_question_with_code(GEST_CODE)
      weight = answer.response.comparable_answer_or_nil_for_question_with_code(WGHT_CODE)

      not answer.comparable_answer == -1 && (gest && gest >= CrossQuestionValidation::GEST_LT) && (weight && weight >= CrossQuestionValidation::WGHT_LT)
    }

    CrossQuestionValidation.register_checker 'special_o2_a', lambda { |answer, unused_related_answer, checker_params|
      raise 'Can only be used on question O2_36wk_' unless answer.question.code == 'O2_36wk_'
  
      #If O2_36wk_ is -1 and (Gest must be <32 or Wght must be <1500) and (Gest+Gestdays + weeks(DOB and the latest date of (LastO2|CeaseCPAPDate|CeaseHiFloDate))) >36
      break true unless (answer.comparable_answer == -1)
  
      # ok if not premature
      break true unless CrossQuestionValidation.check_gest_wght(answer)
  
      gest = answer.response.comparable_answer_or_nil_for_question_with_code(GEST_CODE)
      gest_days = answer.response.comparable_answer_or_nil_for_question_with_code(GEST_DAYS_CODE)
      dob = answer.response.comparable_answer_or_nil_for_question_with_code(DOB_CODE)
  
      last_o2 = answer.response.comparable_answer_or_nil_for_question_with_code(LAST_O2_CODE)
      cease_cpap_date = answer.response.comparable_answer_or_nil_for_question_with_code(CEASE_CPAP_DATE_CODE)
      cease_hi_flo_date = answer.response.comparable_answer_or_nil_for_question_with_code(CEASE_HI_FLO_DATE_CODE)
  
      break false unless dob.present?
      break false unless gest.present?
      break false unless gest_days.present?
      break false unless last_o2.present? || cease_cpap_date.present? || cease_hi_flo_date.present?
  
      dates = [last_o2, cease_cpap_date, cease_hi_flo_date]
      last_date = dates.compact.sort.last
      max_elapsed = last_date - dob
  
      #The actual test (gest in in weeks)
  
      gest.weeks + gest_days.days + max_elapsed.to_i.days > 36.weeks
  
    }
    
    CrossQuestionValidation.register_checker 'special_o2_a_new', lambda { |answer, unused_related_answer, checker_params|
      raise 'Can only be used on question O2_36wk_' unless answer.question.code == 'O2_36wk_'

      #If O2_36wk_ is -1 and (Gest must be <32 or Wght must be <1500) then (Gest+Gestdays + weeks(DOB and the latest date of (LastRespSupp|CeaseCPAPDate|CeaseHiFloDate))) >35
      break true unless (answer.comparable_answer == -1)

      # ok if not premature
      break true unless CrossQuestionValidation.check_gest_wght(answer)

      gest = answer.response.comparable_answer_or_nil_for_question_with_code(GEST_CODE)
      gest_days = answer.response.comparable_answer_or_nil_for_question_with_code(GEST_DAYS_CODE)
      dob = answer.response.comparable_answer_or_nil_for_question_with_code(DOB_CODE)

      last_resp_supp = answer.response.comparable_answer_or_nil_for_question_with_code(LAST_RESP_SUPP_CODE)
      cease_cpap_date = answer.response.comparable_answer_or_nil_for_question_with_code(CEASE_CPAP_DATE_CODE)
      cease_hi_flo_date = answer.response.comparable_answer_or_nil_for_question_with_code(CEASE_HI_FLO_DATE_CODE)

      break true unless dob.present?
      break true unless gest.present?
      break true unless gest_days.present?
      break true unless last_resp_supp.present? || cease_cpap_date.present? || cease_hi_flo_date.present?

      dates = [last_resp_supp, cease_cpap_date, cease_hi_flo_date]
      last_date = dates.compact.sort.last
      max_elapsed = last_date - dob

      #The actual test (gest in in weeks)

      gest.weeks + gest_days.days + max_elapsed.to_i.days > 35.weeks

    }

    CrossQuestionValidation.register_checker 'special_hmeo2', lambda { |answer, unused_related_answer, checker_params|
      raise 'Can only be used on question HmeO2' unless answer.question.code == 'HmeO2'
      # If HmeO2 is -1 and (Gest must be <32 or Wght must be <1500) and HomeDate must be a date and HomeDate must be the same as LastO2
  
      home_date = answer.response.comparable_answer_or_nil_for_question_with_code(HOME_DATE_CODE)
      last_o2 = answer.response.comparable_answer_or_nil_for_question_with_code(LAST_O2_CODE)
  
      #Conditions (IF)
  
      break true unless (answer.comparable_answer == -1) # ok if not -1
      break true unless CrossQuestionValidation.check_gest_wght(answer) # ok if not premature
  
      #Requirements (THEN)
  
      break false unless home_date.present? # bad if homedate blank
      break false unless last_o2.present?
      break false unless last_o2.eql? home_date
  
      true
    }
  
    CrossQuestionValidation.register_checker 'special_hmeo2_new', lambda { |answer, unused_related_answer, checker_params|
      raise 'Can only be used on question HmeO2' unless answer.question.code == 'HmeO2'
      # If HmeO2 is -1 and HomeDate is a date then HomeDate must be the same as LastRespSupp

      home_date = answer.response.comparable_answer_or_nil_for_question_with_code(HOME_DATE_CODE)
      last_resp_supp = answer.response.comparable_answer_or_nil_for_question_with_code(LAST_RESP_SUPP_CODE)

      #Conditions (IF)
      break true unless (answer.comparable_answer == -1) # ok if not -1
      break true unless home_date.present? # bad if homedate blank

      #Requirements (THEN)
      break false unless last_resp_supp.present?
      break false unless last_resp_supp.eql? home_date

      true
    }

    CrossQuestionValidation.register_checker 'special_dob', lambda { |answer, unused_related_answer, checker_params|
      answer.date_answer.year == answer.response.year_of_registration
    }
  
    CrossQuestionValidation.register_checker 'special_rop_prem_rop_vegf_1', lambda { |answer, ununused_related_answer, checker_params|
      #If ROPeligibleExam is -1 and (Gest is <32|Wght is <1500) and ROP is between 1 and 4, ROP_VEGF must be 0 or -1
  
      # if the answer is 0 or -1, no need to check further
      break true if [0, -1].include?(answer.comparable_answer)
  
      break true unless answer.response.comparable_answer_or_nil_for_question_with_code('ROPeligibleExam') == -1
      break true unless (1..4).include?(answer.response.comparable_answer_or_nil_for_question_with_code('ROP'))
      break true unless CrossQuestionValidation.check_gest_wght(answer)
      # if we get here, all the conditions are met, and ROP_VEGF is not 0 or -1, so its an error
      false
    }
  
    CrossQuestionValidation.register_checker 'special_rop_prem_rop_vegf_2', lambda { |answer, ununused_related_answer, checker_params|
      #If ROPeligibleExam is -1 and (Gest is <32|Wght is <1500) and ROP is 0, ROP_VEGF must be 0
  
      # if the answer is 0, no need to check further
      break true if answer.comparable_answer == 0
  
      break true unless answer.response.comparable_answer_or_nil_for_question_with_code('ROPeligibleExam') == -1
      break true unless answer.response.comparable_answer_or_nil_for_question_with_code('ROP') == 0
      break true unless CrossQuestionValidation.check_gest_wght(answer)
      # if we get here, all the conditions are met, and ROP_VEGF is not 0, so its an error
      false
    }
  
    CrossQuestionValidation.register_checker 'special_rop_prem_rop', lambda { |answer, ununused_related_answer, checker_params|
      #If ROPeligibleExam is -1 and (Gest is <32|Wght is <1500), ROP must be between 0 and 4
  
      # if the answer is 1..4, no need to check further
      break true if (0..4).include?(answer.comparable_answer)
  
      break true unless answer.response.comparable_answer_or_nil_for_question_with_code('ROPeligibleExam') == -1
      break true unless CrossQuestionValidation.check_gest_wght(answer)
      # if we get here, all the conditions are met, and ROP is not 0..4, so its an error
      false
    }
  
    CrossQuestionValidation.register_checker 'special_rop_prem_rop_retmaturity', lambda { |answer, ununused_related_answer, checker_params|
      #If ROPeligibleExam is -1 and (Gest is <32|Wght is <1500) and ROP is between 0 and 4, Retmaturity must be -1 or 0
  
      # if the answer is -1 or 0, no need to check further
      break true if [0, -1].include?(answer.comparable_answer)
  
      break true unless answer.response.comparable_answer_or_nil_for_question_with_code('ROPeligibleExam') == -1
      break true unless (0..4).include?(answer.response.comparable_answer_or_nil_for_question_with_code('ROP'))
      break true unless CrossQuestionValidation.check_gest_wght(answer)
      # if we get here, all the conditions are met, and ROP is not 1..4, so its an error
      false
    }
  
    CrossQuestionValidation.register_checker 'special_rop_prem_rop_roprx_1', lambda { |answer, ununused_related_answer, checker_params|
      #If ROPeligibleExam is -1 and (Gest is <32|Wght is <1500) and ROP is 0 or 1 or 5, ROPRx must be 0
  
      # if the answer is -1 or 0, no need to check further
      break true if answer.comparable_answer == 0
  
      break true unless answer.response.comparable_answer_or_nil_for_question_with_code('ROPeligibleExam') == -1
      break true unless [0, 1, 5].include?(answer.response.comparable_answer_or_nil_for_question_with_code('ROP'))
      break true unless CrossQuestionValidation.check_gest_wght(answer)
      # if we get here, all the conditions are met, and ROP is not 1..4, so its an error
      false
    }
  
    CrossQuestionValidation.register_checker 'special_rop_prem_rop_roprx_2', lambda { |answer, ununused_related_answer, checker_params|
      #If ROPeligibleExam is -1 and (Gest is <32|Wght is <1500) and ROP is 3 or 4, ROPRx must be -1
  
      # if the answer is -1 or 0, no need to check further
      break true if answer.comparable_answer == -1
  
      break true unless answer.response.comparable_answer_or_nil_for_question_with_code('ROPeligibleExam') == -1
      break true unless [3, 4].include?(answer.response.comparable_answer_or_nil_for_question_with_code('ROP'))
      break true unless CrossQuestionValidation.check_gest_wght(answer)
      # if we get here, all the conditions are met, and ROP is not 1..4, so its an error
      false
    }
    
    CrossQuestionValidation.register_checker 'special_usd6wk_dob_weeks', lambda { |answer, related_answer, checker_params|
      break true unless related_answer.comparable_answer.present?
      dob = answer.response.comparable_answer_or_nil_for_question_with_code(DOB_CODE)
      break true unless dob
      break true unless CrossQuestionValidation.set_meets_condition?(checker_params[:conditional_set], checker_params[:conditional_set_operator], related_answer.comparable_answer)
      break true unless CrossQuestionValidation.check_gest_wght(answer)
      break false unless answer.comparable_answer.present? # Fail if all conditions have been met so far, but we don't have an answer yet.
  
      elapsed_weeks = (answer.comparable_answer - dob).abs.days / 1.week
      CrossQuestionValidation.set_meets_condition?(checker_params[:set], checker_params[:set_operator], elapsed_weeks)
    }
  
    CrossQuestionValidation.register_checker 'special_namesurg2', lambda { |answer, ununused_related_answer, checker_params|
      #IIf DateSurg2=DateSurg1, Surg_Desc2 must not be the same as Surg_Desc1 (rule on Surg_Desc2)
      raise 'Can only be used on question Surg_Desc2' unless answer.question.code == 'Surg_Desc2'
  
      datesurg1 = answer.response.comparable_answer_or_nil_for_question_with_code('DateSurg1')
      datesurg2 = answer.response.comparable_answer_or_nil_for_question_with_code('DateSurg2')
      break true unless (datesurg1 && datesurg2 && (datesurg1 == datesurg2))
      namesurg1 = answer.response.comparable_answer_or_nil_for_question_with_code('Surg_Desc1')
      break true unless namesurg1 == answer.comparable_answer
    }
  
    CrossQuestionValidation.register_checker 'special_namesurg3', lambda { |answer, ununused_related_answer, checker_params|
      #If DateSurg3=DateSurg2, Surg_Desc3 must not be the same as Surg_Desc2 (rule on Surg_Desc3)
      raise 'Can only be used on question Surg_Desc3' unless answer.question.code == 'Surg_Desc3'
  
      datesurg2 = answer.response.comparable_answer_or_nil_for_question_with_code('DateSurg2')
      datesurg3 = answer.response.comparable_answer_or_nil_for_question_with_code('DateSurg3')
      break true unless (datesurg2 && datesurg3 && (datesurg2 == datesurg3))
      namesurg2 = answer.response.comparable_answer_or_nil_for_question_with_code('Surg_Desc2')
      break true unless namesurg2 == answer.comparable_answer
    }
  
    CrossQuestionValidation.register_checker 'special_cool_hours', lambda { |answer, ununused_related_answer, checker_params|
      #hours between |StartCoolDate+StartCoolTime - CeaseCoolDate+CeaseCoolTime| <=72
      raise 'Can only be used on question StartCoolDate' unless answer.question.code == 'StartCoolDate'

      start_cool_date = answer.response.comparable_answer_or_nil_for_question_with_code('StartCoolDate')
      start_cool_time = answer.response.comparable_answer_or_nil_for_question_with_code('StartCoolTime')
      cease_cool_date = answer.response.comparable_answer_or_nil_for_question_with_code('CeaseCoolDate')
      cease_cool_time = answer.response.comparable_answer_or_nil_for_question_with_code('CeaseCoolTime')
      break true unless start_cool_date && start_cool_time && cease_cool_date && cease_cool_time

      datetime1 = CrossQuestionValidation.aggregate_date_time(start_cool_date, start_cool_time)
      datetime2 = CrossQuestionValidation.aggregate_date_time(cease_cool_date, cease_cool_time)
      hour_difference = (datetime2 - datetime1) / 1.hour

      hour_difference <= 120
    }

    CrossQuestionValidation.register_checker 'special_immun', lambda { |answer, ununused_related_answer, checker_params|
      #If Gest<32|Wght<1500 and days(DOB and HomeDate|DiedDate)>=60, DateImmun must be a date
      # dob is the best place to put this, even though its a bit weird
      raise 'Can only be used on question DOB' unless answer.question.code == 'DOB'

      # we're ok if DateImmun is filled
      break true if answer.response.comparable_answer_or_nil_for_question_with_code('DateImmun')
      # ok if not premature
      break true unless CrossQuestionValidation.check_gest_wght(answer)

      home_date = answer.response.comparable_answer_or_nil_for_question_with_code('HomeDate')
      died_date = answer.response.comparable_answer_or_nil_for_question_with_code('DiedDate')
      # if home date is filled, use that
      if home_date
        days_diff = (home_date - answer.answer_value).to_i
        days_diff < 60
      elsif died_date
        # if died date is filled, use that
        days_diff = (died_date - answer.answer_value).to_i
        days_diff < 60
      else
        # neither is filled, its ok
        true
      end
    }

    CrossQuestionValidation.register_checker 'special_date_of_assess', lambda { |answer, ununused_related_answer, checker_params|
      #DateOfAssess must be greater than DOB+24 months (rule is on DateOfAssess)
      raise 'Can only be used on question DateOfAssess' unless answer.question.code == 'DateOfAssess'

      dob = answer.response.comparable_answer_or_nil_for_question_with_code('DOB')

      break true unless dob
      answer.answer_value > (dob + 24.months)
    }

    CrossQuestionValidation.register_checker 'special_height', lambda { |answer, ununused_related_answer, checker_params|
      #If years between DOB and DateOfAssess is greater than 3, Hght must be between 50 and 100 (rule on Hght)
      raise 'Can only be used on question Hght' unless answer.question.code == 'Hght'

      dob = answer.response.comparable_answer_or_nil_for_question_with_code('DOB')
      doa = answer.response.comparable_answer_or_nil_for_question_with_code('DateOfAssess')
      break true unless dob && doa

      if doa > (dob + 3.years)
        answer.comparable_answer >= 50 && answer.comparable_answer <= 100
      else
        true
      end
    }


    CrossQuestionValidation.register_checker 'special_length', lambda { |answer, ununused_related_answer, checker_params|
      #If years between DOB and DateOfAssess is less than or equal to 3, than Length must be between 50 and 100 (rule on Length)
      raise 'Can only be used on question Length' unless answer.question.code == 'Length'

      dob = answer.response.comparable_answer_or_nil_for_question_with_code('DOB')
      doa = answer.response.comparable_answer_or_nil_for_question_with_code('DateOfAssess')
      break true unless dob && doa

      if doa <= (dob + 3.years)
        answer.comparable_answer >= 50 && answer.comparable_answer <= 100
      else
        true
      end
    }

    CrossQuestionValidation.register_checker 'special_cochimplt', lambda { |answer, ununused_related_answer, checker_params|
      #If Heartest is 2 or 4 and Hearaid is 1 or 2, Cochlmplt must be 1 or 2 (rule on CochImplt)
      raise 'Can only be used on question CochImplt' unless answer.question.code == 'CochImplt'

      heartest = answer.response.comparable_answer_or_nil_for_question_with_code('Heartest')
      hearaid = answer.response.comparable_answer_or_nil_for_question_with_code('Hearaid')
      break true unless heartest && [2, 4].include?(heartest) && hearaid && [1, 2].include?(hearaid)
      [1, 2].include?(answer.comparable_answer)
    }

    CrossQuestionValidation.register_checker 'special_same_name_inf', lambda { |answer, ununused_related_answer, checker_params|
      #If Name_inf2=Name_inf1, days between Date_inf1 and Date_inf2 >14

      no_infection_questions = 4
      /Date_Inf([1-#{no_infection_questions}])/.match(answer.question.code)
      current_question_number = $1
      raise "Can only be used on question Date_InfN - This is #{answer.question.code}, N=#{current_question_number}" unless current_question_number
      current_question_number = current_question_number.to_i

      names = []
      dates = []
      current_infection_name = nil
      no_infection_questions.times do |idx|
        if idx.eql?(current_question_number-1)
          current_infection_name = answer.response.comparable_answer_or_nil_for_question_with_code("Name_Inf#{idx+1}")
        else

          names[idx] = answer.response.comparable_answer_or_nil_for_question_with_code("Name_Inf#{idx+1}")
          dates[idx] = answer.response.comparable_answer_or_nil_for_question_with_code("Date_Inf#{idx+1}")
        end
      end


      break true unless current_infection_name
      break true unless (names.compact.length > 0) && (dates.compact.length > 0)
      passing = true
      names.each_with_index do |name, idx|
        if name.eql?(current_infection_name)
          delta_days = (dates[idx] - answer.comparable_answer).to_i.abs
          passing &= delta_days >= 14
          #raise "#{delta_days.inspect}\n#{name.inspect}\n#{dates[idx].inspect}\n#{conflict.inspect}"
        end
      end

      passing
    }

    CrossQuestionValidation.register_checker 'special_rule22d', lambda { |answer, ununused_related_answer, checker_params|
      #rule22d: n_v_egth + n_s_egth + n_eggs + n_recvd >= n_donate + n_ivf + n_icsi + n_egfz_s + n_egfz_v
      raise 'Can only be used on question N_V_EGTH' unless answer.question.code == 'N_V_EGTH'

      n_v_egth = answer.response.comparable_answer_or_nil_for_question_with_code('N_V_EGTH')
      n_s_egth = answer.response.comparable_answer_or_nil_for_question_with_code('N_S_EGTH')
      n_eggs = answer.response.comparable_answer_or_nil_for_question_with_code('N_EGGS')
      n_recvd = answer.response.comparable_answer_or_nil_for_question_with_code('N_RECVD')
      n_donate = answer.response.comparable_answer_or_nil_for_question_with_code('N_DONATE')
      n_ivf = answer.response.comparable_answer_or_nil_for_question_with_code('N_IVF')
      n_icsi = answer.response.comparable_answer_or_nil_for_question_with_code('N_ICSI')
      n_egfz_s = answer.response.comparable_answer_or_nil_for_question_with_code('N_EGFZ_S')
      n_egfz_v = answer.response.comparable_answer_or_nil_for_question_with_code('N_EGFZ_V')

      # Perform validation check
      (n_v_egth + n_s_egth + n_eggs + n_recvd) >= (n_donate + n_ivf + n_icsi + n_egfz_s + n_egfz_v)
    }

    CrossQuestionValidation.register_checker 'special_rule17_a', lambda { |answer, ununused_related_answer, checker_params|
      # rule17a: if pr_clin is y or u, n_bl_et>0 |n_cl_et >0 | iui_date is a date/present
      raise 'Can only be used on question PR_CLIN' unless answer.question.code == 'PR_CLIN'

      p_r_clin = answer.response.comparable_answer_or_nil_for_question_with_code('PR_CLIN')
      n_bl_et = answer.response.comparable_answer_or_nil_for_question_with_code('N_BL_ET')
      n_cl_et = answer.response.comparable_answer_or_nil_for_question_with_code('N_CL_ET')
      iui_date = answer.response.comparable_answer_or_nil_for_question_with_code('IUI_DATE')

      # If pr_clin not y or u, then validation passes and no more checks required
      break true unless (p_r_clin == 'y' || p_r_clin == 'u')

      # pr_clin is y or u, so do other checks and return valid if one passes
      n_bl_et > 0 || n_cl_et > 0 || !iui_date.nil?
    }

    CrossQuestionValidation.register_checker 'special_rule_gest_iui_date', lambda { |answer, ununused_related_answer, checker_params|
      # rule_xx: if gestational age (pr_end_dt - iui_date) is greater than 20 weeks, n_deliv must be present
      raise 'Can only be used on question PR_END_DT' unless answer.question.code == 'PR_END_DT'

      pr_end_dt = answer.response.comparable_answer_or_nil_for_question_with_code('PR_END_DT')
      iui_date = answer.response.comparable_answer_or_nil_for_question_with_code('IUI_DATE')
      n_deliv = answer.response.comparable_answer_or_nil_for_question_with_code('N_DELIV')

      # Pass if gest age is not greater than 20 weeks (in days)
      break true if (pr_end_dt - iui_date) <= 140

      # Gest age is greater than 20 weeks (in days), check if n_deliv present
      !n_deliv.nil?
    }

    CrossQuestionValidation.register_checker 'special_rule_gest_et_date', lambda { |answer, ununused_related_answer, checker_params|
      # rule_xx: if gestational age (pr_end_dt - et_date) is greater than 20 weeks, n_deliv must be present
      raise 'Can only be used on question PR_END_DT' unless answer.question.code == 'PR_END_DT'

      pr_end_dt = answer.response.comparable_answer_or_nil_for_question_with_code('PR_END_DT')
      et_date = answer.response.comparable_answer_or_nil_for_question_with_code('ET_DATE')
      n_deliv = answer.response.comparable_answer_or_nil_for_question_with_code('N_DELIV')

      # Pass if gest age is not greater than 20 weeks (in days)
      break true if (pr_end_dt - et_date) <= 140

      # Gest age is greater than 20 weeks (in days), check if n_deliv present
      !n_deliv.nil?
    }

    CrossQuestionValidation.register_checker 'special_rule_donor_1', lambda { |answer, ununused_related_answer, checker_params|
      # ruleDonor1: if (n_s_clth + n_v_clth + n_s_blth + n_v_blth) > 0 and don_age is complete, thaw_don must be complete
      raise 'Can only be used on question N_S_CLTH' unless answer.question.code == 'N_S_CLTH'

      n_s_clth = answer.response.comparable_answer_or_nil_for_question_with_code('N_S_CLTH')
      n_v_clth = answer.response.comparable_answer_or_nil_for_question_with_code('N_V_CLTH')
      n_s_blth = answer.response.comparable_answer_or_nil_for_question_with_code('N_S_BLTH')
      n_v_blth = answer.response.comparable_answer_or_nil_for_question_with_code('N_V_BLTH')
      don_age = answer.response.comparable_answer_or_nil_for_question_with_code('DON_AGE')
      thaw_don = answer.response.comparable_answer_or_nil_for_question_with_code('THAW_DON')

      break true if (n_s_clth + n_v_clth + n_s_blth + n_v_blth) <= 0
      break true if don_age.nil?
      !thaw_don.nil?
    }

    CrossQuestionValidation.register_checker 'special_rule_don_age', lambda { |answer, ununused_related_answer, checker_params|
      # ruleDonAge: if surr=y & (n_s_clth + n_v_clth + n_s_blth + n_v_blth) > 0, don_age must be present
      raise 'Can only be used on question SURR' unless answer.question.code == 'SURR'

      surr = answer.response.comparable_answer_or_nil_for_question_with_code('SURR')
      n_s_clth = answer.response.comparable_answer_or_nil_for_question_with_code('N_S_CLTH')
      n_v_clth = answer.response.comparable_answer_or_nil_for_question_with_code('N_V_CLTH')
      n_s_blth = answer.response.comparable_answer_or_nil_for_question_with_code('N_S_BLTH')
      n_v_blth = answer.response.comparable_answer_or_nil_for_question_with_code('N_V_BLTH')
      don_age = answer.response.comparable_answer_or_nil_for_question_with_code('DON_AGE')

      break true if surr != 'y'
      break true if (n_s_clth + n_v_clth + n_s_blth + n_v_blth) <= 0
      !don_age.nil?
    }
  end
end
