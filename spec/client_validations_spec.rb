require File.dirname(__FILE__) + '/spec_helper'

describe Sphinx::Client, 'disconnected' do
  before :each do
    @sphinx = Sphinx::Client.new
  end
  
  context 'in SetServer method' do
    it 'should raise an error when host is not String' do
      expect {
        @sphinx.SetServer(1234, 1234)
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when port is not Integer' do
      expect {
        @sphinx.SetServer('hello', 'world')
      }.to raise_error(ArgumentError)
    end
  end

  context 'in SetConnectTimeout method' do
    it 'should raise an error when timeout is not Integer' do
      expect {
        @sphinx.SetConnectTimeout('timeout')
      }.to raise_error(ArgumentError)
    end
  end
  
  context 'in SetLimits method' do
    it 'should raise an error when offset is not Integer' do
      expect {
        @sphinx.SetLimits('offset', 1, 0, 0)
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when limit is not Integer' do
      expect {
        @sphinx.SetLimits(0, 'limit', 0, 0)
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when max is not Integer' do
      expect {
        @sphinx.SetLimits(0, 1, 'max', 0)
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when cutoff is not Integer' do
      expect {
        @sphinx.SetLimits(0, 1, 0, 'cutoff')
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when offset is less than zero' do
      expect {
        @sphinx.SetLimits(-1, 1, 0, 0)
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when limit is less than 1' do
      expect {
        @sphinx.SetLimits(0, 0, 0, 0)
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when max is less than zero' do
      expect {
        @sphinx.SetLimits(0, 1, -1, 0)
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when cutoff is less than zero' do
      expect {
        @sphinx.SetLimits(0, 1, 0, -1)
      }.to raise_error(ArgumentError)
    end
  end

  context 'in SetMaxQueryTime method' do
    it 'should raise an error when max is not Integer' do
      expect {
        @sphinx.SetMaxQueryTime('max')
      }.to raise_error(ArgumentError)
    end


    it 'should raise an error when max is less than zero' do
      expect {
        @sphinx.SetMaxQueryTime(-1)
      }.to raise_error(ArgumentError)
    end
  end
  
  context 'in SetMatchMode method' do
    it 'should raise an error when mode is not Integer, String or Symbol' do
      expect {
        @sphinx.SetMatchMode([])
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when mode is invalid' do
      expect {
        @sphinx.SetMatchMode('invalid')
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetMatchMode(:invalid)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetMatchMode(100)
      }.to raise_error(ArgumentError)
    end
  end

  context 'in SetRankingMode method' do
    it 'should raise an error when ranker is not Integer, String or Symbol' do
      expect {
        @sphinx.SetRankingMode([])
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when ranker is invalid' do
      expect {
        @sphinx.SetRankingMode('invalid')
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetRankingMode(:invalid)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetRankingMode(100)
      }.to raise_error(ArgumentError)
    end
  end
  
  context 'in SetSortMode method' do
    it 'should raise an error when mode is not Integer, String or Symbol' do
      expect {
        @sphinx.SetSortMode([])
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when mode is invalid' do
      expect {
        @sphinx.SetSortMode('invalid')
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetSortMode(:invalid)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetSortMode(100)
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when sortby is not String' do
      expect {
        @sphinx.SetSortMode(:relevance, [])
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when sortby is empty' do
      expect {
        @sphinx.SetSortMode(:attr_desc)
      }.to raise_error(ArgumentError)
    end
  end
  
  context 'in SetWeights method' do
    it 'should raise an error when weights is not Array' do
      expect {
        @sphinx.SetWeights({})
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when weights is not Array of Integers' do
      expect {
        @sphinx.SetWeights([1, 'a'])
      }.to raise_error(ArgumentError)
    end
  end

  context 'in SetFieldWeights method' do
    it 'should raise an error when weights is not Hash' do
      expect {
        @sphinx.SetFieldWeights([])
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when weights is not Hash map of strings to integers' do
      expect {
        @sphinx.SetFieldWeights('a' => 'b', :c => 5)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetFieldWeights(:a => 'b', :c => 5)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetFieldWeights(1 => 1, :c => 5)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetFieldWeights(1 => 'a', :c => 5)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetFieldWeights(:a => 1, :c => 5)
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetFieldWeights('a' => 1, :c => 5)
      }.to_not raise_error(ArgumentError)
    end
  end

  context 'in SetIndexWeights method' do
    it 'should raise an error when weights is not Hash' do
      expect {
        @sphinx.SetIndexWeights([])
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when weights is not Hash map of strings to integers' do
      expect {
        @sphinx.SetIndexWeights('a' => 'b', :c => 5)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetIndexWeights(:a => 'b', :c => 5)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetIndexWeights(1 => 1, :c => 5)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetIndexWeights(1 => 'a', :c => 5)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetIndexWeights(:a => 1, :c => 5)
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetIndexWeights('a' => 1, :c => 5)
      }.to_not raise_error(ArgumentError)
    end
  end

  context 'in SetIDRange method' do
    it 'should raise an error when min is not Integer' do
      expect {
        @sphinx.SetIDRange('min', 0)
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when max is not Integer' do
      expect {
        @sphinx.SetIDRange(0, 'max')
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when max is less than zero' do
      expect {
        @sphinx.SetIDRange(2, 1)
      }.to raise_error(ArgumentError)
    end
  end

  context 'in SetFilter method' do
    it 'should raise an error when attribute is not String or Symbol' do
      expect {
        @sphinx.SetFilter(1, [1, 2])
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetFilter('attr', [1, 2])
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetFilter(:attr, [1, 2])
      }.to_not raise_error(ArgumentError)
    end

    it 'should raise an error when values is not Array' do
      expect {
        @sphinx.SetFilter(:attr, {})
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when values is not Array of Integers' do
      expect {
        @sphinx.SetFilter(:attr, [1, 'a'])
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when values is empty Array' do
      expect {
        @sphinx.SetFilter(:attr, [])
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when exclude is not Boolean' do
      expect {
        @sphinx.SetFilter(:attr, [1, 2], 'true')
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetFilter(:attr, [1, 2], true)
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetFilter(:attr, [1, 2], false)
      }.to_not raise_error(ArgumentError)
    end
  end

  context 'in SetFilterRange method' do
    it 'should raise an error when attribute is not String or Symbol' do
      expect {
        @sphinx.SetFilterRange(1, 1, 2)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetFilterRange('attr', 1, 2)
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetFilterRange(:attr, 1, 2)
      }.to_not raise_error(ArgumentError)
    end

    it 'should raise an error when min is not Integer' do
      expect {
        @sphinx.SetFilterRange(:attr, 'min', 0)
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when max is not Integer' do
      expect {
        @sphinx.SetFilterRange(:attr, 0, 'max')
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when max is less than zero' do
      expect {
        @sphinx.SetFilterRange(:attr, 2, 1)
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when exclude is not Boolean' do
      expect {
        @sphinx.SetFilterRange(:attr, 1, 2, 'true')
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetFilterRange(:attr, 1, 2, true)
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetFilterRange(:attr, 1, 2, false)
      }.to_not raise_error(ArgumentError)
    end
  end

  context 'in SetFilterFloatRange method' do
    it 'should raise an error when attribute is not String or Symbol' do
      expect {
        @sphinx.SetFilterFloatRange(1, 1, 2)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetFilterFloatRange('attr', 1, 2)
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetFilterFloatRange(:attr, 1, 2)
      }.to_not raise_error(ArgumentError)
    end

    it 'should raise an error when min is not Integer or Float' do
      expect {
        @sphinx.SetFilterFloatRange(:attr, 'min', 1)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetFilterFloatRange(:attr, 0, 1)
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetFilterFloatRange(:attr, 0.1, 1)
      }.to_not raise_error(ArgumentError)
    end

    it 'should raise an error when max is not Integer or Float' do
      expect {
        @sphinx.SetFilterFloatRange(:attr, 0, 'max')
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetFilterFloatRange(:attr, 0, 1)
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetFilterFloatRange(:attr, 0, 1.1)
      }.to_not raise_error(ArgumentError)
    end

    it 'should raise an error when max is less than zero' do
      expect {
        @sphinx.SetFilterFloatRange(:attr, 2, 1)
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when exclude is not Boolean' do
      expect {
        @sphinx.SetFilterFloatRange(:attr, 1, 2, 'true')
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetFilterFloatRange(:attr, 1, 2, true)
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetFilterFloatRange(:attr, 1, 2, false)
      }.to_not raise_error(ArgumentError)
    end
  end

  context 'in SetGeoAnchor method' do
    it 'should raise an error when attrlat is not String or Symbol' do
      expect {
        @sphinx.SetGeoAnchor(1, 'attrlong', 1, 2)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetGeoAnchor('attrlat', 'attrlong', 1, 2)
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetGeoAnchor(:attrlat, 'attrlong', 1, 2)
      }.to_not raise_error(ArgumentError)
    end

    it 'should raise an error when attrlong is not String or Symbol' do
      expect {
        @sphinx.SetGeoAnchor('attrlat', 1, 1, 2)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetGeoAnchor('attrlat', 'attrlong', 1, 2)
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetGeoAnchor('attrlat', :attrlong, 1, 2)
      }.to_not raise_error(ArgumentError)
    end

    it 'should raise an error when lat is not Integer or Float' do
      expect {
        @sphinx.SetGeoAnchor('attrlat', 'attrlong', 'a', 2)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetGeoAnchor('attrlat', 'attrlong', 1, 2)
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetGeoAnchor('attrlat', 'attrlong', 1.1, 2)
      }.to_not raise_error(ArgumentError)
    end

    it 'should raise an error when long is not Integer or Float' do
      expect {
        @sphinx.SetGeoAnchor('attrlat', 'attrlong', 1, 'a')
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetGeoAnchor('attrlat', 'attrlong', 1, 2)
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetGeoAnchor('attrlat', 'attrlong', 1.1, 2)
      }.to_not raise_error(ArgumentError)
    end
  end

  context 'in SetGroupBy method' do
    it 'should raise an error when attribute is not String or Symbol' do
      expect {
        @sphinx.SetGroupBy(1, :day)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetGroupBy('attr', :day)
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetGroupBy(:attr, :day)
      }.to_not raise_error(ArgumentError)
    end

    it 'should raise an error when func is invalid' do
      expect {
        @sphinx.SetGroupBy(:attr, 'invalid')
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetGroupBy(:attr, :invalid)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetGroupBy(:attr, 100)
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when groupsort is not String' do
      expect {
        @sphinx.SetGroupBy(1, :day, 1)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetGroupBy('attr', :day, 'groupsort')
      }.to_not raise_error(ArgumentError)
    end
  end

  context 'in SetGroupDistinct method' do
    it 'should raise an error when attribute is not String or Symbol' do
      expect {
        @sphinx.SetGroupDistinct(1)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetGroupDistinct('attr')
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetGroupDistinct(:attr)
      }.to_not raise_error(ArgumentError)
    end
  end

  context 'in SetRetries method' do
    it 'should raise an error when count is not Integer' do
      expect {
        @sphinx.SetRetries('count', 0)
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when delay is not Integer' do
      expect {
        @sphinx.SetRetries(0, 'delay')
      }.to raise_error(ArgumentError)
    end
  end

  context 'in SetOverride method' do
    it 'should raise an error when attribute is not String or Symbol' do
      expect {
        @sphinx.SetOverride(1, :integer, {})
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetOverride('attr', :integer, {})
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetOverride(:attr, :integer, {})
      }.to_not raise_error(ArgumentError)
    end

    it 'should raise an error when attrtype is invalid' do
      expect {
        @sphinx.SetOverride(:attr, 'invalid', {})
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetOverride(:attr, :invalid, {})
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetOverride(:attr, 100, {})
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when values is not Hash' do
      expect {
        @sphinx.SetOverride(:attr, :integer, [])
      }.to raise_error(ArgumentError)
    end

    it "should raise an error when values Hash keys are not Integers" do
      expect {
        @sphinx.SetOverride(:attr, :integer, { 'a' => 10 })
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetOverride(:attr, :integer, { 10 => 10 })
      }.to_not raise_error(ArgumentError)
    end

    [:integer, :ordinal, :bool, :bigint].each do |attrtype|
      it "should raise an error when attrtype is \"#{attrtype}\" and values Hash values are not Integers" do
        expect {
          @sphinx.SetOverride(:attr, attrtype, { 10 => '10' })
        }.to raise_error(ArgumentError)

        expect {
          @sphinx.SetOverride(:attr, attrtype, { 10 => 10 })
        }.to_not raise_error(ArgumentError)
      end
    end

    it "should raise an error when attrtype is \"timestamp\" and values Hash values are not Integers or Time" do
      expect {
        @sphinx.SetOverride(:attr, :timestamp, { 10 => '10' })
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetOverride(:attr, :timestamp, { 10 => 10 })
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetOverride(:attr, :timestamp, { 10 => Time.now })
      }.to_not raise_error(ArgumentError)
    end

    it "should raise an error when attrtype is \"float\" and values Hash values are not Integers or Floats" do
      expect {
        @sphinx.SetOverride(:attr, :float, { 10 => '10' })
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetOverride(:attr, :float, { 10 => 10 })
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.SetOverride(:attr, :float, { 10 => 10.1 })
      }.to_not raise_error(ArgumentError)
    end
  end
  
  context 'in SetSelect method' do
    it 'should raise an error when select is not String' do
      expect {
        @sphinx.SetSelect(:select)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetSelect(1)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.SetSelect('select')
      }.to_not raise_error(ArgumentError)
    end
  end
  
  context 'in BuildExcerpts method' do
    it 'should raise an error when docs is not Array of Strings' do
      expect {
        @sphinx.BuildExcerpts(1, 'index', 'words')
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.BuildExcerpts('doc', 'index', 'words')
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.BuildExcerpts([1], 'index', 'words')
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.BuildExcerpts(['doc'], 'index', 'words')
      }.to_not raise_error(ArgumentError)
    end

    it 'should raise an error when index is not String or Symbol' do
      expect {
        @sphinx.BuildExcerpts(['doc'], 1, 'words')
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.BuildExcerpts(['doc'], 'index', 'words')
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.BuildExcerpts(['doc'], :index, 'words')
      }.to_not raise_error(ArgumentError)
    end

    it 'should raise an error when words is not String' do
      expect {
        @sphinx.BuildExcerpts(['doc'], 'index', 1)
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when opts is not Hash' do
      expect {
        @sphinx.BuildExcerpts(['doc'], 'index', 'words', [])
      }.to raise_error(ArgumentError)
    end
  end

  context 'in BuildKeywords method' do
    it 'should raise an error when query is not String' do
      expect {
        @sphinx.BuildExcerpts([], 'index', true)
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when index is not String or Symbol' do
      expect {
        @sphinx.BuildKeywords('query', 1, true)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.BuildKeywords('query', 'index', true)
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.BuildKeywords('query', :index, true)
      }.to_not raise_error(ArgumentError)
    end

    it 'should raise an error when hits is not Boolean' do
      expect {
        @sphinx.BuildKeywords('query', :index, 1)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.BuildKeywords('query', :index, true)
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.BuildKeywords('query', :index, false)
      }.to_not raise_error(ArgumentError)
    end
  end

  context 'in UpdateAttributes method' do
    it 'should raise an error when index is not String or Symbol' do
      expect {
        @sphinx.UpdateAttributes(1, [:attr1, :attr2], { 10 => [1, 2], 20 => [3, 4] }, false)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.UpdateAttributes('index', [:attr1, :attr2], { 10 => [1, 2], 20 => [3, 4] }, false)
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.UpdateAttributes(:index, [:attr1, :attr2], { 10 => [1, 2], 20 => [3, 4] }, false)
      }.to_not raise_error(ArgumentError)
    end

    it 'should raise an error when mva is not Boolean' do
      expect {
        @sphinx.UpdateAttributes('index', [:attr1, :attr2], { 10 => [1, 2], 20 => [3, 4] }, 1)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.UpdateAttributes('index', [:attr1, :attr2], { 10 => [1, 2], 20 => [3, 4] }, false)
      }.to_not raise_error(ArgumentError)

      expect {
        @sphinx.UpdateAttributes('index', [:attr1, :attr2], { 10 => [[1], [2]], 20 => [[3], [4]] }, true)
      }.to_not raise_error(ArgumentError)
    end

    it 'should raise an error when values is not Hash' do
      expect {
        @sphinx.UpdateAttributes('index', [:attr1, :attr2], [], 1)
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when mva is false and values is not Hash map of Integers to Arrays of Integers' do
      expect {
        @sphinx.UpdateAttributes('index', [:attr1, :attr2], { 'a' => [1, 2], 20 => [3, 4] }, false)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.UpdateAttributes('index', [:attr1, :attr2], { 10 => [1, 2], 20 => ['3', 4] }, false)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.UpdateAttributes('index', [:attr1, :attr2], { 10 => [1, 2], 20 => 5 }, false)
      }.to raise_error(ArgumentError)
    end

    it 'should raise an error when mva is true and values is not Hash map of Integers to Arrays of Arrays of Integers' do
      expect {
        @sphinx.UpdateAttributes('index', [:attr1, :attr2], { 'a' => [[1], [2]], 20 => [[3], [4]] }, true)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.UpdateAttributes('index', [:attr1, :attr2], { 10 => [[1], [2]], 20 => 5 }, true)
      }.to raise_error(ArgumentError)

      expect {
        @sphinx.UpdateAttributes('index', [:attr1, :attr2], { 10 => [[1], [2]], 20 => [3, [4]] }, true)
      }.to raise_error(ArgumentError)
    end
  end
end
