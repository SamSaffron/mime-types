module MIME
  ValuePool = Hash.new { |h,k|
    begin
      k = k.dup
    rescue TypeError
    else
      k.freeze
    end

    h[k] = k
  }
end
