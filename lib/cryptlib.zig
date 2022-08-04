pub usingnamespace @cImport({
    @cInclude("cryptlib.h");
});

const c = @cImport({
    @cInclude("cryptlib.h");
});

pub const CryptError = error {
    Param1,
    Param2,
    Param3,
    Param4,
    Param5,
    Param6,
    Param7,
    Failed,
    Inited,
    Memory,
    NoSecure,
    NotInited,
    Random,
    Complete,
    Incomplete,
    Invalid,
    NotAvail,
    Permission,
    Signalled,
    Timeout,
    WrongKey,
    BadData,
    Overflow,
    Signature,
    Underflow,
    Duplicate,
    NotFound,
    Open,
    Read,
    Write,
    EnvelopeResource,
    Unknown
};

pub fn ok(status: c_int) CryptError!void {
    switch (status) {
        c.CRYPT_OK => return,
        c.CRYPT_ERROR_PARAM1 => return error.Param1,
        c.CRYPT_ERROR_PARAM2 => return error.Param2,
        c.CRYPT_ERROR_PARAM3 => return error.Param3,
        c.CRYPT_ERROR_PARAM4 => return error.Param4,
        c.CRYPT_ERROR_PARAM5 => return error.Param5,
        c.CRYPT_ERROR_PARAM6 => return error.Param6,
        c.CRYPT_ERROR_PARAM7 => return error.Param7,
        c.CRYPT_ERROR_FAILED => return error.Failed,
        c.CRYPT_ERROR_INITED => return error.Inited,
        c.CRYPT_ERROR_MEMORY => return error.Memory,
        c.CRYPT_ERROR_NOSECURE => return error.NoSecure,
        c.CRYPT_ERROR_NOTINITED => return error.NotInited,
        c.CRYPT_ERROR_RANDOM => return error.Random,
        c.CRYPT_ERROR_COMPLETE => return error.Complete,
        c.CRYPT_ERROR_INCOMPLETE => return error.Incomplete,
        c.CRYPT_ERROR_INVALID => return error.Invalid,
        c.CRYPT_ERROR_NOTAVAIL => return error.NotAvail,
        c.CRYPT_ERROR_PERMISSION => return error.Permission,
        c.CRYPT_ERROR_SIGNALLED => return error.Signalled,
        c.CRYPT_ERROR_TIMEOUT => return error.Timeout,
        c.CRYPT_ERROR_WRONGKEY => return error.WrongKey,
        c.CRYPT_ERROR_BADDATA => return error.BadData,
        c.CRYPT_ERROR_OVERFLOW => return error.Overflow,
        c.CRYPT_ERROR_SIGNATURE => return error.Signature,
        c.CRYPT_ERROR_UNDERFLOW => return error.Underflow,
        c.CRYPT_ERROR_DUPLICATE => return error.Duplicate,
        c.CRYPT_ERROR_NOTFOUND => return error.NotFound,
        c.CRYPT_ERROR_OPEN => return error.Open,
        c.CRYPT_ERROR_READ => return error.Read,
        c.CRYPT_ERROR_WRITE => return error.Write,
        c.CRYPT_ENVELOPE_RESOURCE => return error.EnvelopeResource,
        else => return error.Unknown
    }
}
