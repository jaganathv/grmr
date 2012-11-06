require "sequitur"

class Grammar
  attr_accessor :rules, :start
  def initialize()
    # string
    @start = nil
    # string -> (GSymbol array) map
    @rules = {}
    # cache the results for expanding a var
    @expandCache = {}
  end

  def addRule(left,right)
    @rules[left] = right
    resetCache()
  end

  # replace all occurences of varold with the sequence newseq
  def substVar(varold,newseq)
    @rules.each do |curLeft,curRight|
      isChanged = false
      curRight.map! do |sym|
        if (sym.isVar && sym.token == varold)
          isChanged = true
          next newseq
        else
          next sym
        end
      end
      curRight.flatten! if isChanged
    end
  end
  # replaces all occurrences of (varold: string) with (varnew: string) and removes
  # rule for varold
  # if the rule for varnew contains a copy of varold, copy in the old rhs
  def replaceVar(varold,varnew)
    raise unless (@rules.has_key? varold and @rules.has_key? varnew)
    if(varold == @start) then @start = varnew end
    symnew = GSymbol.new(true,varnew)
    symold = GSymbol.new(true,varold)

    # annoying case where varnew contains a copy of varold
    if (@rules[varnew].include? symold)
      oldrhs = @rules[varold]
      @rules[varnew].map! do |sym|
        if (sym.isVar && sym.token == varold)
          next oldrhs
        else
          next sym
        end
      end
      @rules[varnew].flatten!
    end

    @rules.delete(varold)
    substVar(varold,[symnew])
    resetCache()
  end
  # replace varold with its rhs and remove rule for varold
  def inlineVar(varold)
    raise unless (@rules.has_key? varold)
    raise if (varold==@start)
    rhsold = @rules[varold]
    @rules.delete(varold)
    substVar(varold,rhsold)
  end

  # returns the array of terminal symbols generated by curVar : string
  def expandVar(curVar)
    raise unless (curVar.class == String)
    # if the result is already cached, use the cache
    if (@expandCache.has_key? curVar) then 
      return @expandCache[curVar] 
    end
    curSeq = @rules[curVar]
    nextVarInd = curSeq.index {|sym| sym.isVar}
    # recursively replace variables until only terminals left
    until nextVarInd == nil
      #nextVar : string
      nextVar = curSeq[nextVarInd].token
      repText = expandVar(nextVar)
      curSeq = curSeq.map do |sym|
        if (sym.isVar && sym.token == nextVar)
          next repText
        else
          next sym
        end
      end
      curSeq = curSeq.flatten
      nextVarInd = curSeq.index {|sym| sym.isVar}
    end
    @expandCache[curVar] = curSeq
    return curSeq
  end
  def expandAns()
    return expandVar(@start)
  end
  
  def resetCache()
    @expandCache = {}
  end
  def countVars
    varcount = {}
    @rules.each_key do |curleft|
      varcount[curleft] = 0
    end
    varcount[@start] = 2
    @rules.each_value do |curright|
      curright.each do |cursym|
        if(cursym.isVar) then
          varcount[cursym.token] += 1
        end
      end
    end
    return varcount
  end

  def to_s()
    out = "Start: "+@start.to_s+"\n"
    @rules.each do |curLeft,curRight|
      out += (curLeft)+":>"+(curRight.to_s)+"\n"
    end
    return out
  end

  # Begin reduction methods for making a grammar irreducible-------
  # ----------------------------------------------------------------
  # so far have only implemented rule #1 from "grammar based codes"
  
  def reduceGramm
    progress = true
    while progress
      progress = remSingle()
    end
  end
  def remSingle
    varcount = countVars()
    varcount.each do |curvar,curcount|
      if (curcount>1) then
        next
      else
        inlineVar(curvar)
        return true
      end
    end
    return false
  end
end

class GSymbol
  attr_accessor :token, :isVar
  def initialize(isVar,token)
    @isVar = isVar
    @token = token
  end
  def to_s
    return @token
  end
  def ==(symbol2)
    raise unless @isVar == symbol2.isVar
    return (@token == symbol2.token and @isVar == symbol2.isVar)
  end
end

# string sequence -> symbol list for debugging purposes
def createSymList(strSeq)
  outArr = []
  strSeq.split("").each do |c|
    if (c.upcase == c)
      outArr << GSymbol.new(true,c)
    else
      outArr << GSymbol.new(false,c)
    end
  end
  return outArr
end


# Converts from the linked-list CFG format used in sequitur to
# the array + dictionary CFG format here. Algorithm stolen from
# puts_grammar

def convert_seq(seqGrammar)
  newGramm = Grammar.new()

  curRules = [seqGrammar]
  nonterminals = {"*" => true}
  newGramm.start = "*"
  curRules.each do |rule|
    newVar = rule.token
    newSeq = []
    nextsym = rule.next
    until nextsym.is_head? do
      if not nextsym.rule.nil?
        curRules << nextsym.rule if not nonterminals[nextsym.token]
        nonterminals[nextsym.token] = true
        newSeq << GSymbol.new(true,nextsym.token)
      else
        newSeq << GSymbol.new(false,nextsym.token)
      end
      nextsym = nextsym.next
    end
    newGramm.addRule(newVar,newSeq)
  end
  return newGramm
end

=begin
str = "aactgaacatgagagacatagagacag"
gramm1 = Sequitur.new(str).run
myGrammar = convert_seq(gramm1)
puts myGrammar.expandVar("*").to_s
myGrammar.replaceVar("E","D")
puts myGrammar.to_s
=end