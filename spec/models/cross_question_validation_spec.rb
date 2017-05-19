require 'rails_helper'

describe CrossQuestionValidation do
  describe "Associations" do
    it { should belong_to :question }
    it { should belong_to :related_question }
  end
  describe "Validations" do
    it { should validate_presence_of :question_id }
    it { should validate_presence_of :rule }
    it { should validate_presence_of :error_message }
    context "should check that comparison CQVs have safe operators" do
      specify { build(:cross_question_validation, rule: 'comparison', operator: '').should_not be_valid }
      specify { build(:cross_question_validation, rule: 'comparison', operator: '>').should be_valid }
      specify do
        cqv = build(:cross_question_validation, rule: 'comparison', operator: 'dodgy_operator')
        cqv.should_not be_valid
        cqv.errors.messages[:base].should include("dodgy_operator not included in #{%w(== <= >= < > !=)}")
      end
    end
    context "should check that comparison CQVs have numerical offset constants" do
      # Blank offset
      specify { build(:cross_question_validation, rule: 'comparison', operator: '>', constant: nil).should be_valid }
      specify { build(:cross_question_validation, rule: 'comparison', operator: '>', constant: '').should be_valid }
      # Numerical offset
      specify { build(:cross_question_validation, rule: 'comparison', operator: '>', constant: 0).should be_valid }
      specify { build(:cross_question_validation, rule: 'comparison', operator: '>', constant: '0').should be_valid }
      specify { build(:cross_question_validation, rule: 'comparison', operator: '>', constant: '-1.5').should be_valid }
      # Invalid offset (any non-numerical text)
      specify { build(:cross_question_validation, rule: 'comparison', operator: '>', constant: 'y').should_not be_valid }
      specify { build(:cross_question_validation, rule: 'comparison', operator: '>', constant: 'one').should_not be_valid }
      specify do
        cqv = build(:cross_question_validation, rule: 'comparison', operator: '>', constant: 'some text')
        cqv.should_not be_valid
        cqv.errors.messages[:base].should include("invalid cqv offset \"some text\" - constant offset must be an integer or decimal")
      end
    end
    it "should validate that the rule is one of the allowed rules" do
      CrossQuestionValidation.valid_rules.each do |value|
        should allow_value(value).for(:rule)
      end
      build(:cross_question_validation, rule: 'Blahblah').should_not be_valid
    end
    it "should validate only one of related question, or related question list populated" do
      # 0 0 F
      # 0 1 T
      # 1 0 T
      # 1 1 F

      build(:cross_question_validation, related_question_id: nil, related_question_ids: nil).should_not be_valid
      build(:cross_question_validation, related_question_id: nil, related_question_ids: [1]).should be_valid
      build(:cross_question_validation, related_question_id: 1, related_question_ids: nil).should be_valid
      build(:cross_question_validation, related_question_id: 1, related_question_ids: [1]).should_not be_valid

    end
    it "should validate that a CQV is only applied to question codes that they apply to" do
      bad_q = create(:question, code: 'some_rubbish_question_code')
      SpecialRules::RULE_CODES_REQUIRING_PARTICULAR_QUESTION_CODES.each do |rule_code, required_question_code|
        good_q = create(:question, code: required_question_code)

        build(:cross_question_validation, rule: rule_code, question: bad_q).should_not be_valid
        build(:cross_question_validation, rule: rule_code, question: good_q).should be_valid
      end
    end
  end

  describe "helpers" do
    ALL_OPERATORS = %w(* / + - % ** == != > < >= <= <=> === eql? equal? = += -+ *= /+ %= **= & | ^ ~ << >> and or && || ! not ?: .. ...)
    UNSAFE_OPERATORS = ALL_OPERATORS - CrossQuestionValidation::SAFE_OPERATORS
    # ToDo: Text safe operators for textual constants
    describe 'safe operators' do

      it "should accept 'safe' operators" do
        CrossQuestionValidation::SAFE_OPERATORS.each do |op|
          CrossQuestionValidation.is_operator_safe?(op).should eq true
        end
      end
      it "should reject 'unsafe' operators" do
        UNSAFE_OPERATORS.each do |op|
          CrossQuestionValidation.is_operator_safe?(op).should eq false
        end
      end
    end

    # ToDo: Test set operators for textual constants
    describe 'valid set operators' do

      it "should accept valid operators" do
        CrossQuestionValidation::ALLOWED_SET_OPERATORS.each do |op|
          CrossQuestionValidation.is_set_operator_valid?(op).should eq true
        end
      end
      it "should reject invalid operators" do
        CrossQuestionValidation.is_set_operator_valid?("invalid_operator").should eq false
        CrossQuestionValidation.is_set_operator_valid?("something_else").should eq false

      end
    end

    # ToDo: text set conditions for textual constants
    describe 'set_meets_conditions' do
      it "should pass true statements" do
        CrossQuestionValidation.set_meets_condition?([1, 3, 5, 7], "included", 5).should eq true
        CrossQuestionValidation.set_meets_condition?([1, 3, 5, 7], "excluded", 4).should eq true
        CrossQuestionValidation.set_meets_condition?([1, 5], "range", 4).should eq true
        CrossQuestionValidation.set_meets_condition?([1, 5], "range", 1).should eq true
        CrossQuestionValidation.set_meets_condition?([1, 5], "range", 5).should eq true
        CrossQuestionValidation.set_meets_condition?([1, 5], "range", 4.9).should eq true
        CrossQuestionValidation.set_meets_condition?([1, 5], "range", 1.1).should eq true
      end

      it "should reject false statements" do
        CrossQuestionValidation.set_meets_condition?([1, 3, 5, 7], "included", 4).should eq false
        CrossQuestionValidation.set_meets_condition?([1, 3, 5, 7], "excluded", 5).should eq false
        CrossQuestionValidation.set_meets_condition?([1, 5], "range", 0).should eq false
        CrossQuestionValidation.set_meets_condition?([1, 5], "range", 6).should eq false
        CrossQuestionValidation.set_meets_condition?([1, 5], "range", 5.1).should eq false
      end

      # ToDo: test unsafe operators are rejected for textual constant sets
      it "should reject statements with invalid operators" do
        CrossQuestionValidation.set_meets_condition?([1, 3, 5], "swirly", 0).should eq false
        CrossQuestionValidation.set_meets_condition?([1, 3, 5], "includified", 0).should eq false
      end
    end

    describe 'const_meets_conditions' do
      it "should pass true statements" do
        CrossQuestionValidation.const_meets_condition?(0, "==", 0).should eq true
        CrossQuestionValidation.const_meets_condition?(5, "!=", 3).should eq true
        CrossQuestionValidation.const_meets_condition?(5, ">=", 3).should eq true
      end

      it "should reject false statements" do
        CrossQuestionValidation.const_meets_condition?(0, "<", 0).should eq false
        CrossQuestionValidation.const_meets_condition?(5, "==", 3).should eq false
        CrossQuestionValidation.const_meets_condition?(5, "<=", 3).should eq false
      end

      # ToDo: test unsafe operators are rejected for textual constants
      it "should reject statements with unsafe operators" do
        CrossQuestionValidation.const_meets_condition?(0, UNSAFE_OPERATORS.first, 0).should eq false
        CrossQuestionValidation.const_meets_condition?(0, UNSAFE_OPERATORS.last, 0).should eq false
      end
    end
  end


  describe "check" do
    before :each do
      @survey = create :survey
      @section = create :section, survey: @survey
    end

    def do_cqv_check (first, val)
      error_messages = CrossQuestionValidation.check first
      error_messages.should eq val
    end

    def standard_cqv_test(val_first, val_second, error)
      first = create :answer, response: @response, question: @q1, answer_value: val_first
      second = create :answer, response: @response, question: @q2, answer_value: val_second

      @response.reload

      do_cqv_check(first, error)
    end

    def three_question_cqv_test(val_first, val_second, val_third, error)
      first = create :answer, response: @response, question: @q1, answer_value: val_first
      second = create :answer, response: @response, question: @q2, answer_value: val_second
      third = create :answer, response: @response, question: @q3, answer_value: val_third

      @response.reload

      do_cqv_check(first, error)
    end

    describe "implications" do
      before :each do
        @response = create :response, survey: @survey
      end
      describe 'date implies constant' do
        before :each do
          @error_message = 'q2 was date, q1 was not expected constant (-1)'
          @q1 = create :question, section: @section, question_type: 'Integer'
          @q2 = create :question, section: @section, question_type: 'Date'
          create :cqv_present_implies_constant, question: @q1, related_question: @q2, error_message: @error_message, operator: '==', constant: -1
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("doesn't reject the LHS when RHS not a date") { standard_cqv_test({}, "5", []) }
        it("rejects when RHS is date and LHS is not expected constant") { standard_cqv_test(5, Date.new(2012, 2, 3), [@error_message]) }
        it("accepts when RHS is date and LHS is expected constant") { standard_cqv_test(-1, Date.new(2012, 2, 1), []) }
      end

      describe 'present implies constant (textual constant)' do
        before :each do
          @error_message = 'if q2 is present, q1 must be y'
          @q1 = create :question, section: @section, question_type: 'Text'
          @q2 = create :question, section: @section, question_type: 'Integer'
          create :cqv_present_implies_constant, question: @q1, related_question: @q2, error_message: @error_message, operator: '==', constant: 'y'
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("rejects when RHS is present and LHS is not expected constant") { standard_cqv_test('n', 0, [@error_message]) }
        it("accepts when RHS is present and LHS is expected constant") { standard_cqv_test('y', 0, []) }
      end

      describe 'constant implies constant' do
        before :each do
          @error_message = 'q2 was != 0, q1 was not > 0'
          @q1 = create :question, section: @section, question_type: 'Integer'
          @q2 = create :question, section: @section, question_type: 'Integer'
          create :cqv_const_implies_const, question: @q1, related_question: @q2, error_message: @error_message
          #conditional_operator "!="
          #conditional_constant 0
          #operator ">"
          #constant 0
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("doesn't reject the LHS when RHS not expected constant") { standard_cqv_test(-1, 0, []) }
        it("rejects when RHS is specified constant and LHS is not expected constant") { standard_cqv_test(-1, 1, [@error_message]) }
        it("accepts when RHS is specified constant and LHS is expected constant") { standard_cqv_test(1, 1, []) }
      end

      describe 'constant implies constant (textual constant)' do
        before :each do
          @error_message = 'if q2 > 0, q1 must be y'
          @q1 = create :question, section: @section, question_type: 'Text'
          @q2 = create :question, section: @section, question_type: 'Integer'
          create :cqv_const_implies_const, question: @q1, related_question: @q2, error_message: @error_message,
                 conditional_operator: '>', conditional_constant: 0, operator: '==', constant: 'y'
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("doesn't reject the LHS when RHS not expected constant") { standard_cqv_test('n', 0, []) }
        it("rejects when RHS is specified constant and LHS is not expected constant") { standard_cqv_test('n', 1, [@error_message]) }
        it("accepts when RHS is specified constant and LHS is expected constant") { standard_cqv_test('y', 1, []) }
      end

      # ToDo: test for textual constants and sets
      describe 'constant implies set' do
        before :each do
          @error_message = 'q2 was != 0, q1 was not in specified set [1,3,5,7]'
          @q1 = create :question, section: @section, question_type: 'Integer'
          @q2 = create :question, section: @section, question_type: 'Integer'
          create :cqv_const_implies_set, question: @q1, related_question: @q2, error_message: @error_message
          #conditional_operator "!="
          #conditional_constant 0
          #set_operator "included"
          #set [1,3,5,7]
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("doesn't reject the LHS when RHS not expected constant") { standard_cqv_test(-1, 0, []) }
        it("rejects when RHS is specified const and LHS is not in expected set") { standard_cqv_test(0, 1, [@error_message]) }
        it("accepts when RHS is specified const and LHS is in expected set") { standard_cqv_test(1, 1, []) }
      end

      # ToDo: test for textual constants and sets
      describe 'set implies set' do
        before :each do
          @error_message = 'q2  was in [2,4,6,8], q1 was not in specified set [1,3,5,7]'
          @q1 = create :question, section: @section, question_type: 'Integer'
          @q2 = create :question, section: @section, question_type: 'Integer'
          create :cqv_set_implies_set, question: @q1, related_question: @q2, error_message: @error_message
          #conditional_set_operator "included"
          #conditional_set [2,4,6,8]
          #set_operator "included"
          #set [1,3,5,7]
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("doesn't reject the LHS when RHS not in expected set") { standard_cqv_test(-1, 0, []) }
        it("rejects when RHS is in specified set and LHS is in expected set") { standard_cqv_test(0, 2, [@error_message]) }
        it("accepts when RHS is in specified set and LHS is in expected set") { standard_cqv_test(1, 2, []) }
      end

      describe 'present implies present' do
        before :each do
          @error_message = 'q2 must be answered if q1 is'
          @q1 = create :question, section: @section, question_type: 'Date'
          @q2 = create :question, section: @section, question_type: 'Time'
          create :cqv_present_implies_present, question: @q1, related_question: @q2, error_message: @error_message
        end
        it("is not run if the question has a badly formed answer") { standard_cqv_test("2011-12-", "11:53", []) }
        it("passes if both are answered") { standard_cqv_test("2011-12-12", "11:53", []) }
        it "fails if the question is answered and the related question is not" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "2011-12-12"
          do_cqv_check(a1, [@error_message])
        end
        it("fails if the question is answered and the related question has an invalid answer") { standard_cqv_test("2011-12-12", "11:", [@error_message]) }
      end

      describe 'const implies present' do
        before :each do
          @error_message = 'q2 must be answered if q1 matches constant'
          @q1 = create :question, section: @section, question_type: 'Integer'
          @q2 = create :question, section: @section, question_type: 'Date'
          create :cqv_const_implies_present, question: @q1, related_question: @q2, error_message: @error_message, operator: '==', constant: -1
        end
        it("is not run if the question has a badly formed answer") { standard_cqv_test("ab", "2011-12-12", []) }
        it("passes if both are answered and answer to question == constant") { standard_cqv_test("-1", "2011-12-12", []) }
        it("passes if both are answered and answer to question != constant") { standard_cqv_test("99", "2011-12-12", []) }
        it "fails if related question not answered and answer to question == constant" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "-1"
          do_cqv_check(a1, [@error_message])
        end
        it "passes if related question not answered and answer to question != constant" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "00"
          do_cqv_check(a1, [])
        end
        it("fails if related question has an invalid answer and answer to question == constant") { standard_cqv_test("-1", "2011-12-", [@error_message]) }
      end

      describe 'const implies present (textual constant)' do
        before :each do
          @error_message = 'q2 must be answered if q1 matches constant'
          @q1 = create :question, section: @section, question_type: 'Text'
          @q2 = create :question, section: @section, question_type: 'Date'
          create :cqv_const_implies_present, question: @q1, related_question: @q2, error_message: @error_message, operator: '==', constant: 'yes'
        end
        it("is not run if the question has a badly formed answer") { standard_cqv_test("ab", "2011-12-12", []) }
        it("passes if both are answered and answer to question == constant") { standard_cqv_test("yes", "2011-12-12", []) }
        it("passes if both are answered and answer to question != constant") { standard_cqv_test("no", "2011-12-12", []) }
        it "fails if related question not answered and answer to question == constant" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "yes"
          do_cqv_check(a1, [@error_message])
        end
        it "passes if related question not answered and answer to question != constant" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "no"
          do_cqv_check(a1, [])
        end
        it("fails if related question has an invalid answer and answer to question == constant") { standard_cqv_test("yes", "2011-12-", [@error_message]) }
      end

      # ToDo: test for textual set
      describe 'set implies present' do
        before :each do
          @error_message = 'q2 must be answered if q1 is in [2..7]'
          @q1 = create :question, section: @section, question_type: 'Choice'
          @q2 = create :question, section: @section, question_type: 'Date'
          create :cqv_set_implies_present, question: @q1, related_question: @q2, error_message: @error_message, set_operator: 'range', set: [2, 7]
        end
        it("is not run if the question has a badly formed answer") { standard_cqv_test("ab", "2011-12-12", []) }
        it("passes if both are answered and answer to question is at start of set") { standard_cqv_test("2", "2011-12-12", []) }
        it("passes if both are answered and answer to question is in middle of set") { standard_cqv_test("5", "2011-12-12", []) }
        it("passes if both are answered and answer to question is at end of set") { standard_cqv_test("7", "2011-12-12", []) }
        it "fails if related question not answered and answer to question is at start of set" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "2"
          do_cqv_check(a1, [@error_message])
        end
        it "fails if related question not answered and answer to question is in middle of set" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "5"
          do_cqv_check(a1, [@error_message])
        end
        it "fails if related question not answered and answer to question is at end of set" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "7"
          do_cqv_check(a1, [@error_message])
        end
        it "passes if related question not answered and answer to question is outside range" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "8"
          do_cqv_check(a1, [])
        end
        it("fails if related question has an invalid answer and answer to question in range") { standard_cqv_test("3", "2011-12-", [@error_message]) }
      end

      describe 'const implies one of const' do
        before :each do
          @error_message = 'q2 or q3 must be -1 if q1 is 99'
          @q1 = create :question, section: @section, question_type: 'Integer'
          @q2 = create :question, section: @section, question_type: 'Integer'
          @q3 = create :question, section: @section, question_type: 'Integer'
          @cqv1 = create :cqv_const_implies_one_of_const, question: @q1, related_question: nil, related_question_ids: [@q2.id, @q3.id], error_message: @error_message, operator: '==', constant: 99, conditional_operator: '==', conditional_constant: -1
        end
        it("handles nils") { three_question_cqv_test(99, nil, nil, [@error_message]) }
        it("passes when q1 is not 99 and neither q2 or q3 are -1") { three_question_cqv_test(0, 0, 0, []) }
        it("fails when q1 is 99 but neither q2 or q3 are -1") { three_question_cqv_test(99, 0, 0, [@error_message]) }
        it("passes when q1 is 99 and q2 is -1 but q3 is not") { three_question_cqv_test(99, -1, -0, []) }
        it("passes when q1 is 99 and q2 is not -1 but q3 is") { three_question_cqv_test(99, 0, -1, []) }
        it("passes when q1 is 99 and both q2 and q3 are -1") { three_question_cqv_test(99, -1, -1, []) }
      end

      describe 'const implies one of const (textual constants)' do
        before :each do
          @error_message = 'q2 or q3 must be "yes" if q1 is "true"'
          @q1 = create :question, section: @section, question_type: 'Text'
          @q2 = create :question, section: @section, question_type: 'Text'
          @q3 = create :question, section: @section, question_type: 'Text'
          @cqv1 = create :cqv_const_implies_one_of_const, question: @q1, related_question: nil, related_question_ids: [@q2.id, @q3.id], error_message: @error_message, operator: '==', constant: 'true', conditional_operator: '==', conditional_constant: 'yes'
        end
        it("handles nils") { three_question_cqv_test('true', nil, nil, [@error_message]) }
        it("passes when q1 is not 'true' and neither q2 or q3 are 'yes'") { three_question_cqv_test('false', 'no', 'no', []) }
        it("fails when q1 is 'true' but neither q2 or q3 are 'yes'")  { three_question_cqv_test('true', 'no', 'no', [@error_message]) }
        it("passes when q1 is 'true' and q2 is 'yes' but q3 is not") { three_question_cqv_test('true', 'yes', 'no', []) }
        it("passes when q1 is 'true' and q2 is not 'yes' but q3 is") { three_question_cqv_test('true', 'no', 'yes', []) }
        it("passes when q1 is 'true' and both q2 and q3 are 'yes'") { three_question_cqv_test('true', 'yes', 'yes', []) }
      end
    end

    describe "Blank Unless " do
      before :each do
        @response = create :response, survey: @survey
      end

      describe 'blank if constant (q must be blank if related q == constant)' do
        # e.g. If Died_ is 0, DiedDate must be blank (rule is on DiedDate)
        before :each do
          @error_message = 'if q2 == -1, q1 must be blank'
          @q1 = create :question, section: @section, question_type: 'Integer'
          @q2 = create :question, section: @section, question_type: 'Integer'
          create :cqv_blank_if_const, question: @q1, related_question: @q2, error_message: @error_message, conditional_operator: '==', conditional_constant: -1
        end
        it "passes if q2 not answered but q1 is" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "7"
        end
        it("passes if q2 not answered and q1 not answered") {} # rule won't be run
        it("passes if q2 is not -1 and q1 is blank") {} # rule won't be run }
        it("passes if q2 is not -1 and q1 is not blank") { standard_cqv_test(123, 0, []) }
        it("passes when q2 is -1 and q1 is blank") {} # rule won't be run }
        it("fails when q2 is -1 and q1 is not blank") { standard_cqv_test(123, -1, [@error_message]) }
      end

      describe 'blank if constant (textual constant)' do
        # e.g. If Died_ is 0, DiedDate must be blank (rule is on DiedDate)
        before :each do
          @error_message = 'if q2 == n, q1 must be blank'
          @q1 = create :question, section: @section, question_type: 'Integer'
          @q2 = create :question, section: @section, question_type: 'Text'
          create :cqv_blank_if_const, question: @q1, related_question: @q2, error_message: @error_message, conditional_operator: '==', conditional_constant: 'n'
        end
        it "passes if q2 not answered but q1 is" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "7"
        end
        it("passes if q2 not answered and q1 not answered") {} # rule won't be run
        it("passes if q2 is not specified constant and q1 is blank") {} # rule won't be run }
        it("passes if q2 is not specified constant and q1 is not blank") { standard_cqv_test(123, 'y', []) }
        it("passes when q2 is specified constant and q1 is blank") {} # rule won't be run }
        it("fails when q2 is specified constant and q1 is not blank") { standard_cqv_test(123, 'n', [@error_message]) }
      end
    end

    describe "Present Unless " do
      before :each do
        @response = create :response, survey: @survey
      end

      describe 'present if constant (q must be present if related q == constant)' do
        # e.g. If Died_ is 0, DiedDate must be blank (rule is on DiedDate)
        before :each do
          @error_message = 'if q2 == -1, q1 must be present'
          @q1 = create :question, section: @section, question_type: 'Integer'
          @q2 = create :question, section: @section, question_type: 'Integer'
          create :cqv_present_if_const, question: @q1, related_question: @q2, error_message: @error_message, conditional_operator: '==', conditional_constant: -1
        end
        it "passes if q2 not answered but q1 is" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "7"
          do_cqv_check(a1, [])
        end
        it("passes if q2 not answered and q1 answered") {} # rule won't be run
        it("passes if q2 is not -1 and q1 is blank") { standard_cqv_test({}, 0, []) }
        it("passes if q2 is not -1 and q1 is not blank") {} # rule won't be run
        it("passes when q2 is -1 and q1 is not blank") {} # rule won't be run
        it("fails when q2 is -1 and q1 is blank") { standard_cqv_test({}, -1, [@error_message]) }
      end

      describe 'present if constant (textual constant)' do
        # e.g. If Died_ is y, DiedDate must be present (rule is on DiedDate)
        before :each do
          @error_message = 'if q2 == y, q1 must be present'
          @q1 = create :question, section: @section, question_type: 'Integer'
          @q2 = create :question, section: @section, question_type: 'Text'
          create :cqv_present_if_const, question: @q1, related_question: @q2, error_message: @error_message, conditional_operator: '==', conditional_constant: 'y'
        end
        it "passes if q2 not answered but q1 is" do
          a1 = create :answer, response: @response, question: @q1, answer_value: "7"
          do_cqv_check(a1, [])
        end
        it("passes if q2 not answered and q1 answered") {} # rule won't be run
        it("passes if q2 is not specified constant and q1 is blank") { standard_cqv_test({}, 'n', []) }
        it("passes if q2 is not specified constant and q1 is not blank") {} # rule won't be run
        it("passes when q2 is specified constant and q1 is not blank") {} # rule won't be run
        it("fails when q2 is specified constant and q1 is blank") { standard_cqv_test({}, 'y', [@error_message]) }
      end
    end

    describe "comparisons (using dates to represent a complex type that supports <,>,== etc)" do
      before :each do
        @q1 = create :question, section: @section, question_type: 'Date'
        @q2 = create :question, section: @section, question_type: 'Date'
        @response = create :response, survey: @survey
        @response.reload
        @response.answers.count.should eq 0
      end
      describe "date_lte" do
        before :each do
          @error_message = 'not lte'
          create :cross_question_validation, rule: 'comparison', operator: '<=', question: @q1, related_question: @q2, error_message: @error_message
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("rejects gt") { standard_cqv_test(Date.new(2012, 2, 3), Date.new(2012, 2, 2), [@error_message]) }
        it("accepts lt") { standard_cqv_test(Date.new(2012, 2, 1), Date.new(2012, 2, 2), []) }
        it("accepts eq") { standard_cqv_test(Date.new(2012, 2, 2), Date.new(2012, 2, 2), []) }
      end
      describe "date_gte" do
        before :each do
          @error_message = 'not gte'
          create :cross_question_validation, rule: 'comparison', operator: '>=', question: @q1, related_question: @q2, error_message: @error_message
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("accepts gt") { standard_cqv_test(Date.new(2012, 2, 3), Date.new(2012, 2, 2), []) }
        it("rejects lt") { standard_cqv_test(Date.new(2012, 2, 1), Date.new(2012, 2, 2), [@error_message]) }
        it("accepts eq") { standard_cqv_test(Date.new(2012, 2, 2), Date.new(2012, 2, 2), []) }
      end
      describe "date_gt" do
        before :each do
          @error_message = 'not gt'
          create :cross_question_validation, rule: 'comparison', operator: '>', question: @q1, related_question: @q2, error_message: @error_message
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("accepts gt") { standard_cqv_test(Date.new(2012, 2, 3), Date.new(2012, 2, 2), []) }
        it("rejects lt") { standard_cqv_test(Date.new(2012, 2, 1), Date.new(2012, 2, 2), [@error_message]) }
        it("rejects eq") { standard_cqv_test(Date.new(2012, 2, 2), Date.new(2012, 2, 2), [@error_message]) }
      end
      describe "date_lt" do
        before :each do
          @error_message = 'not lt'
          create :cross_question_validation, rule: 'comparison', operator: '<', question: @q1, related_question: @q2, error_message: @error_message
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("rejects gt") { standard_cqv_test(Date.new(2012, 2, 3), Date.new(2012, 2, 2), [@error_message]) }
        it("accepts lt") { standard_cqv_test(Date.new(2012, 2, 1), Date.new(2012, 2, 2), []) }
        it("rejects eq") { standard_cqv_test(Date.new(2012, 2, 2), Date.new(2012, 2, 2), [@error_message]) }
      end
      describe "date_eq" do
        before :each do
          @error_message = 'not eq'
          create :cross_question_validation, rule: 'comparison', operator: '==', question: @q1, related_question: @q2, error_message: @error_message
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("rejects gt") { standard_cqv_test(Date.new(2012, 2, 3), Date.new(2012, 2, 2), [@error_message]) }
        it("rejects lt") { standard_cqv_test(Date.new(2012, 2, 1), Date.new(2012, 2, 2), [@error_message]) }
        it("accepts eq") { standard_cqv_test(Date.new(2012, 2, 2), Date.new(2012, 2, 2), []) }
      end
      describe "date_ne" do
        before :each do
          @error_message = 'are eq'
          create :cross_question_validation, rule: 'comparison', operator: '!=', question: @q1, related_question: @q2, error_message: @error_message
        end
        it("handles nils") { standard_cqv_test({}, {}, []) }
        it("accepts gt") { standard_cqv_test(Date.new(2012, 2, 3), Date.new(2012, 2, 2), []) }
        it("accepts lt") { standard_cqv_test(Date.new(2012, 2, 1), Date.new(2012, 2, 2), []) }
        it("rejects eq") { standard_cqv_test(Date.new(2012, 2, 2), Date.new(2012, 2, 2), [@error_message]) }
      end
      
      describe "comparisons with offsets function normally" do
        #This isn't much to test here: We're utilising the other class' ability to use +/-, so as long
        # As it works for one case involving a 'complex' type, that's good enough.
        before :each do
          @error_message = 'not eq'
        end
        it "accepts X eq Y (offset +1) when Y = X-1" do
          create :cross_question_validation, rule: 'comparison', operator: '==', question: @q1, related_question: @q2, error_message: @error_message, constant: 1
          standard_cqv_test(Date.new(2012, 2, 3), Date.new(2012, 2, 2), [])
        end
        it "rejects X eq Y (offset +1) when Y = X" do
          create :cross_question_validation, rule: 'comparison', operator: '==', question: @q1, related_question: @q2, error_message: @error_message, constant: 1
          standard_cqv_test(Date.new(2012, 2, 1), Date.new(2012, 2, 1), [@error_message])
        end
        it "accepts X eq Y (offset -1) when Y = X+1" do
          create :cross_question_validation, rule: 'comparison', operator: '==', question: @q1, related_question: @q2, error_message: @error_message, constant: -1
          standard_cqv_test(Date.new(2012, 2, 3), Date.new(2012, 2, 4), [])
        end
        it "rejects X eq Y (offset -1) when Y = X" do
          create :cross_question_validation, rule: 'comparison', operator: '==', question: @q1, related_question: @q2, error_message: @error_message, constant: -1
          standard_cqv_test(Date.new(2012, 2, 1), Date.new(2012, 2, 1), [@error_message])
        end
        it "accepts X eq Y (offset \"+1.00\") when Y = X-1" do
          create :cross_question_validation, rule: 'comparison', operator: '==', question: @q1, related_question: @q2, error_message: @error_message, constant: '1.00'
          standard_cqv_test(Date.new(2012, 2, 3), Date.new(2012, 2, 2), [])
        end
        it "rejects X eq Y (offset \"+1.00\") when Y = X" do
          create :cross_question_validation, rule: 'comparison', operator: '==', question: @q1, related_question: @q2, error_message: @error_message, constant: '1.00'
          standard_cqv_test(Date.new(2012, 2, 1), Date.new(2012, 2, 1), [@error_message])
        end
        it "accepts X eq Y (offset \"-1.00\") when Y = X+1" do
          create :cross_question_validation, rule: 'comparison', operator: '==', question: @q1, related_question: @q2, error_message: @error_message, constant: '-1.00'
          standard_cqv_test(Date.new(2012, 2, 3), Date.new(2012, 2, 4), [])
        end
        it "rejects X eq Y (offset \"-1.00\") when Y = X" do
          create :cross_question_validation, rule: 'comparison', operator: '==', question: @q1, related_question: @q2, error_message: @error_message, constant: '-1.00'
          standard_cqv_test(Date.new(2012, 2, 1), Date.new(2012, 2, 1), [@error_message])
        end
      end
    end
  end

  describe 'check if premature' do
    before(:each) do
      @gest_q = create(:question, code: 'Gest', question_type: Question::TYPE_INTEGER)
      @wght_q = create(:question, code: 'Wght', section: @gest_q.section, question_type: Question::TYPE_INTEGER)
    end

    it 'should return false if neither gest nor gest wgt answered' do
      check_gest_wght(nil, nil, nil)       # it returns nil for false in this case

    end
    it 'should return true if gest < 32 OR wght < 1500' do
      check_gest_wght(31, nil, true)
      check_gest_wght(31, 1499, true)
      check_gest_wght(31, 1500, true)
      check_gest_wght(31, 1501, true)

      check_gest_wght(32, nil, nil)# it returns nil for false in this case
      check_gest_wght(32, 1499, true)
      check_gest_wght(32, 1500, false)
      check_gest_wght(32, 1501, false)

      check_gest_wght(33, nil, nil)# it returns nil for false in this case
      check_gest_wght(33, 1499, true)
      check_gest_wght(33, 1500, false)
      check_gest_wght(33, 1501, false)
    end

    def check_gest_wght(gest, wght, expected_result)
      response = create(:response, survey: @gest_q.section.survey)
      create(:answer, question: @gest_q, answer_value: gest, response: response) unless gest.nil?
      create(:answer, question: @wght_q, answer_value: wght, response: response) unless wght.nil?
      any_answer = create(:answer, response: response)
      any_answer.reload
      CrossQuestionValidation.check_gest_wght(any_answer).should eq(expected_result)
    end
  end
end
