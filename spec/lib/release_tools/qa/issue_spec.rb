require 'spec_helper'

describe ReleaseTools::Qa::Issue do
  let(:version) { ReleaseTools::Version.new('10.8.0-rc1') }
  let(:current_date) { DateTime.new(2018, 9, 10, 16, 40, 0, '+2') }
  let(:project) { ReleaseTools::Project::GitlabCe }
  let(:mr1) do
    double(
      "title" => "Resolve \"Import/Export (import) is broken due to the addition of a CI table\"",
      "author" => double("username" => "author"),
      "assignee" => double("username" => "assignee"),
      "labels" => [
        "Platform",
        "bug",
        "import",
        "project export",
        "regression"
      ],
      "sha" => "4f04aeec80bbfcb025e321693e6ca99b01244bb4",
      "merge_commit_sha" => "0065c449ff95cf6e0643bab17ed236c23207b537",
      "web_url" => "https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/18745",
      "merged_by" => double("username" => "merger")
    )
  end

  let(:merge_requests) { [mr1] }

  let(:args) do
    {
      version: version,
      project: project,
      merge_requests: merge_requests
    }
  end

  it_behaves_like 'issuable #create', :create_issue
  it_behaves_like 'issuable #update', :update_issue
  it_behaves_like 'issuable #remote_issuable', :find_issue

  subject { described_class.new(args) }

  describe '#title' do
    it "returns the correct issue title" do
      expect(subject.title).to eq '10.8.0-rc1 QA Issue'
    end
  end

  describe '#description' do
    context 'for a new issue' do
      before do
        expect(subject).to receive(:exists?).and_return(false)
        @content = Timecop.freeze(current_date) { subject.description }
      end

      it "includes the current release version" do
        expect(@content).to include("## Merge Requests tested in 10.8.0-rc1")
      end

      it "includes the Team label title" do
        expect(@content).to include('### Platform')
      end

      it "includes the MR information" do
        expect(@content).to include('Import/Export (import) is broken due to the addition of a CI table')
        expect(@content).to include('gitlab-org/gitlab-ce!18745')
      end

      it "includes the MR author" do
        expect(@content).to include("@author")
      end

      it "includes the qa task for version" do
        expect(@content).to include("## Automated QA for 10.8.0-rc1")
      end

      it 'includes the due date' do
        expect(@content).to include('2018-09-11 14:40 UTC')
      end

      context 'for RC2' do
        let(:version) { ReleaseTools::Version.new('10.8.0-rc2') }

        it 'the due date is 12h in the future' do
          expect(@content).to include('2018-09-11 02:40 UTC')
        end
      end
    end

    context 'for an existing issue' do
      let(:previous_revision) { 'Previous Revision' }
      let(:remote_issuable) do
        double(description: previous_revision)
      end

      before do
        expect(subject).to receive(:exists?).and_return(true)
        expect(subject).to receive(:remote_issuable).and_return(remote_issuable)
        @content = subject.description
      end

      it "includes previous revision" do
        expect(@content).to include("Previous Revision")
      end
    end
  end

  describe '#labels' do
    it 'returns a list of labels' do
      expect(subject.labels).to eq 'QA task'
    end
  end

  describe '#add_comment' do
    let(:comment_body) { "comment body" }
    let(:remote_issue_iid) { 1234 }
    let(:remote_issuable) { double(iid: remote_issue_iid) }

    before do
      expect(subject).to receive(:comment_body).and_return(comment_body)
      expect(subject).to receive(:remote_issuable).and_return(remote_issuable)
    end

    it "calls the api to create a comment" do
      expect(ReleaseTools::GitlabClient).to receive(:create_issue_note).with(project, issue: remote_issuable, body: comment_body)

      subject.add_comment
    end
  end

  describe '#comment_body' do
    it 'has the correct content' do
      expect(subject.comment_body).to eq("New QA items for: @author")
    end
  end

  describe '#link!' do
    it 'links to its parent issue' do
      issue = described_class.new(version: version)

      allow(issue).to receive(:parent_issue).and_return('parent')
      expect(ReleaseTools::GitlabClient).to receive(:link_issues).with(issue, 'parent')

      issue.link!
    end
  end
end