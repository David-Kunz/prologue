import httpcore
import strtabs, strutils, strformat, parseutils, tables

type
  # TODO add FileUpload object
  FormPart* = object
    data*: OrderedTableRef[string, tuple[params: StringTableRef, body: string]]


proc initFormPart*(): FormPart {.inline.} =
  FormPart(data: newOrderedTable[string, (StringTableRef, string)]())

proc `[]`*(formPart: FormPart, key: string): tuple[params: StringTableRef,
    body: string] =
  formPart.data[key]

proc `[]=`*(formPart: FormPart, key: string, body: string) =
  formPart.data[key] = (newStringTable(), body)

proc parseFormPart*(body, contentType: string): FormPart {.inline.} =
  # parse form
  let
    sep = contentType[contentType.rfind("boundary") + 9 .. ^1]
    startSep = fmt"--{sep}"
    endSep = fmt"--{sep}--"
    startPos = find(body, startSep)
    endPos = rfind(body, endSep)
    formData = body[startPos ..< endPos]
    formDataSeq = formData.split(startSep & "\c\L")

  result = initFormPart()

  for data in formDataSeq:
    if data.len == 0:
      continue

    var
      pos = 0
      head, tail: string
      name: string
      times = 0
      tok = ""
      formKey, formValue: string

    pos += parseUntil(data, head, "\c\L\c\L")
    pos += 4
    tail = data[pos ..< ^1]

    if not head.startsWith("Content-Disposition"):
      break

    for line in head.splitLines:
      let header = line.parseHeader
      if header.key != "Content-Disposition":
        result.data[name].params[header.key] = header.value[0]
        continue
      pos = 0
      let
        content = header.value[0]
        length = content.len
      pos += parseUntil(content, tok, ';', pos)

      while pos < length:
        pos += skipWhile(content, {';', ' '}, pos)
        pos += parseUntil(content, formKey, '=', pos)
        pos += skipWhile(content, {'=', '\"'}, pos)
        pos += parseUntil(content, formValue, '\"', pos)
        pos += skipWhile(content, {'\"'}, pos)

        case formKey
        of "name":
          name = formValue
          result.data[name] = (newStringTable(), "")
        of "filename":
          result.data[name].params["fileName"] = formValue
        of "filename*":
          result.data[name].params["fileNameStar"] = formValue
        else:
          discard
        times += 1
        if times >= 3:
          break

    result.data[name].body = tail