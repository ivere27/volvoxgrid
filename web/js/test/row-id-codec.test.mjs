// Run after `npm run build`: node --test test/row-id-codec.test.mjs
import assert from "node:assert/strict";
import test from "node:test";
import {
  AfterEditEvent,
  BeforeEditEvent,
  CellEditValidateEvent,
  CreateRequest,
  EditorSession,
  GetRowsRequest,
  LoadTableRequest,
  RowDef,
  RowIdentity,
  StartEditEvent,
} from "../dist/generated/volvoxgrid_lite.js";

const ids = [1n, 9007199254740993n, 9223372036854775807n];

test("row ID tracking requires an explicit creation option", () => {
  const legacy = new CreateRequest();
  assert.equal(legacy.rowIdsEnabled, false);
  assert.deepEqual([...legacy.toBinary()], []);
  assert.equal(CreateRequest.fromBinary(new Uint8Array()).rowIdsEnabled, false);
  for (const enabled of [false, true]) {
    const message = new CreateRequest({ rowIdsEnabled: enabled });
    // This codec preserves explicitly supplied false; omitted remains empty.
    assert.deepEqual([...message.toBinary()], enabled ? [40, 1] : [40, 0]);
    assert.equal(CreateRequest.fromBinary(message.toBinary()).rowIdsEnabled, enabled);
  }
});

test("row IDs preserve the full positive int64 range in protobuf and JSON", () => {
  for (const rowId of ids) {
    const row = new RowIdentity({ index: 7, rowId });
    const decoded = RowIdentity.fromBinary(row.toBinary());
    assert.equal(typeof decoded.rowId, "bigint");
    assert.equal(decoded.rowId, rowId);
    assert.equal(decoded.toJson().rowId, rowId.toString());
  }
  const maximum = new RowIdentity({ index: 7, rowId: ids[2] });
  assert.deepEqual([...maximum.toBinary()], [
    8, 7, 16, 255, 255, 255, 255, 255, 255, 255, 255, 127,
  ]);
});

test("bulk load and reverse lookup IDs retain packed int64 precision", () => {
  for (const Message of [LoadTableRequest, GetRowsRequest]) {
    const message = new Message({ rowIds: ids });
    assert.deepEqual(Message.fromBinary(message.toBinary()).rowIds, ids);
  }
});

test("row definitions and edit events retain maximum int64 IDs", () => {
  for (const Message of [
    RowDef, EditorSession, BeforeEditEvent, StartEditEvent, AfterEditEvent,
    CellEditValidateEvent,
  ]) {
    const message = new Message({ rowId: ids[2] });
    assert.equal(Message.fromBinary(message.toBinary()).rowId, ids[2]);
  }
});
