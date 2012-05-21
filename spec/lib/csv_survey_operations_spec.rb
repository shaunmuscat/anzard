require 'spec_helper'

include CsvSurveyOperations

def fqn(filename)
  # fully-qualified name.
  Rails.root.join('test_data', 'survey', filename)
end

def counts_should_eq_0(*models)
  counts = models.map { |m| m.count }
  counts.should eq ([0] * models.length)
end

describe CsvSurveyOperations do
  describe "create_survey" do

    let(:good_question_file) { fqn('survey_questions.csv') }
    let(:bad_question_file) { fqn('bad_questions.csv') }
    let(:good_options_file) { fqn('survey_options.csv') }
    let(:bad_options_file) { fqn('bad_options.csv') }
    let(:good_cqv_file) { fqn('cross_question_validations.csv') }
    let(:bad_cqv_file) { fqn('bad_cross_question_validations.csv') }

    it "works on good input" do
      s = create_survey('some_name', good_question_file, good_options_file, good_cqv_file)
      s.sections.count.should eq 2
      s.sections.first.questions.count.should eq 6
      s.sections.second.questions.count.should eq 3

      Section.find_by_name!('0').section_order.should eq 0
      Section.find_by_name!('1').section_order.should eq 1
    end

    it "should be transactional with a bad cqv file" do
      begin
        create_survey('some name', good_question_file, good_options_file, bad_cqv_file)
        raise 'not supposed to get here'
      rescue ActiveRecord::RecordNotFound
        # expected due to incorrect question code
      end
      counts_should_eq_0 Survey, Question, CrossQuestionValidation, Answer, Response, QuestionOption

    end

    it "should be transactional with a bad options file" do
      begin
        create_survey('some name', good_question_file, bad_options_file, good_cqv_file)
        raise 'not supposed to get here'
      rescue ActiveRecord::RecordInvalid
        # expected due to duplicate option order
      end
      counts_should_eq_0 Survey, Question, CrossQuestionValidation, Answer, Response, QuestionOption

    end
    it "should be transactional with a bad question file" do
      begin
        create_survey('some name', bad_question_file, good_options_file, good_cqv_file)
        raise 'not supposed to get here'
      rescue ActiveRecord::RecordInvalid
        # expected due to duplicate question order
      end
      counts_should_eq_0 Survey, Question, CrossQuestionValidation, Answer, Response, QuestionOption
    end
  end

  describe "make_cqvs" do
    pending
  end

  describe "make_cqv" do
    def run_make_cqv_test(survey, label_to_cqv_id, hash)
      begin
        make_cqv(survey, label_to_cqv_id, hash)
        continued = true
      rescue
        continued = false
      end

      continued
    end

    before :each do
      @survey = Factory :survey
      @section = Factory :section, survey: @survey
      @error_message = 'q2 was date, q1 was not expected constant (-1)'
      @q1 = Factory :question, section: @section, question_type: 'Integer', code: "q1"
      @q2 = Factory :question, section: @section, question_type: 'Integer', code: "q2"
      @q3 = Factory :question, section: @section, question_type: 'Integer', code: "q3"

      @multi_related_hash = {"related_question_list" => "q2, q3",
                             "rule" => "multi_hours_date_to_date",
                             "operator" => "<=",
                             "constant" => "0",
                             "error_message" => "Err",
                             "question_code" => "q1",
                             "primary" => true}

      @multi_rule_secondary_hash = {"primary" => false,
                                    "rule_label" => "secondary",
                                    "rule" => "comparison",
                                    "operator" => "==",
                                    "question_code" => "q1",
                                    "related_question_code" => "q2"}


      @multi_rule_primary_hash = {"primary" => true,
                                  "rule_label_list" => "secondary, secondary",
                                  "rule" => "multi_rule_any_pass",
                                  "error_message" => "Err",
                                  "question_code" => "q1"}

    end
    it 'should accept if it can map question lists to questions' do
      run_make_cqv_test(@survey, {}, @multi_related_hash).should be_true
    end

    it 'should reject if it can\'t map question lists to questions' do
      new_hash = @multi_related_hash
      new_hash['related_question_list'] = "q2, q3, q4"
      run_make_cqv_test(@survey, {}, new_hash).should be_false
    end

    it "should accept if it can map related rule labels to rules" do
      label_hash = {}
      make_cqv(@survey, label_hash, @multi_rule_secondary_hash) # add a secondary rule
      run_make_cqv_test(@survey, label_hash, @multi_rule_primary_hash).should be_true
    end
    it "should reject if it can't map related rule labels to rules" do
      label_hash = {}
      run_make_cqv_test(@survey, label_hash, @multi_rule_primary_hash).should be_false
    end
  end
end
