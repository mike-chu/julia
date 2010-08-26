symbol(s::String) =
    ccall(dlsym(JuliaDLHandle,"jl_symbol"), Any, (Ptr{Char},), s)::Symbol

gensym() = ccall(dlsym(JuliaDLHandle,"jl_gensym"), Any, ())::Symbol

string(x) =
    ccall(dlsym(JuliaDLHandle,"jl_cstr_to_array"), Any, (Ptr{Char},),
          ccall(dlsym(JuliaDLHandle,"jl_print_to_string"), Ptr{Char}, (Any,),
                x))::String

strcat(ss::String...) = vcat(ss...)

function escape_char(c::Uint8)
    if 31 < c < 127
        return c == "\\"[1] ? "\\\\" : [c]
    end
    if c == 0
        return "\\0"
    end
    if 7 <= c <= 13
        return ["\\",["abtnvfr"[c-6]]]
    end
    if c == 127
        return "\\e"
    end
    ["\\0",lpad(uint2str(c,8),2,"0"[1])]
end

function escape_string(raw::String)
    esc = ""
    for i = 1:length(raw)
        esc = [esc, escape_char(raw[i])]
    end
    return esc
end

function unescape_string(esc::String)
    raw = ""
    i = 1
    while i <= length(esc)
        if i < length(esc) && esc[i] == "\\"[1]
            e = esc[i+1]
            i += 2
            c = e == "a"[1] ?   7 :
                e == "b"[1] ?   8 :
                e == "t"[1] ?   9 :
                e == "n"[1] ?  10 :
                e == "v"[1] ?  11 :
                e == "f"[1] ?  12 :
                e == "r"[1] ?  13 :
                e == "e"[1] ? 127 :
                e == "0"[1] ? begin
                    x = 0
                    while i <= length(esc)
                        if !("0"[1] <= esc[i] <= "7"[1])
                            break
                        end
                        x = 8*x + (esc[i]-"0"[1])
                        i += 1
                    end
                    if 255 < x
                        error("invalid octal character escape")
                    end
                    x
                end : e
            raw = [raw, [uint8(c)]]
        else
            raw = [raw, [esc[i]]]
            i += 1
        end
    end
    return raw
end

function lpad(s,n,char)
    k = length(s)
    if k >= n
        return s
    end
    p = Array(Uint8,n)
    for i=1:n-k; p[i] = char; end
    for i=1:k; p[n-k+i] = s[i]; end
    p
end

function rpad(s,n,char)
    k = length(s)
    if k >= n
        return s
    end
    p = Array(Uint8,n)
    for i=1:k; p[i] = s[i]; end
    for i=1:n-k; p[k+i] = char; end
    p
end

## string to integer functions ##

function parse_digit(c::Uint8)
    "0"[1] <= c <= "9"[1] ? int32(c - "0"[1]) :
    "A"[1] <= c <= "Z"[1] ? int32(c - "A"[1]) + 10 :
    "a"[1] <= c <= "z"[1] ? int32(c - "a"[1]) + 10 :
    error("non alphanumeric digit")
end

function parse_int(T::Type{Int}, str::String, base::Int)
    n = zero(T)
    b = one(T)
    for p = 0:length(str)-1
        d = parse_digit(str[length(str)-p])
        if base <= d
            error("digit not valid in base")
        end
        n += d*b
        b *= base
    end
    return n
end

bin(str::String) = parse_int(Int64, str,  2)
oct(str::String) = parse_int(Int64, str,  8)
dec(str::String) = parse_int(Int64, str, 10)
hex(str::String) = parse_int(Int64, str, 16)

## integer to string ##

function uint2str(n::Int, base::Int)
    ndig = n==convert(typeof(n),0) ? 1 : int32(floor(log(n)/log(base)+1))
    sz = ndig+1
    str = Array(Uint8, sz)
    ccall(dlsym(JuliaDLHandle,"uint2str"), Ptr{Uint8},
          (Ptr{Uint8}, Size, Uint64, Uint32),
          str, sz, uint64(n), uint32(base))
    str[:(sz-1)]  # cut out terminating nul
end
