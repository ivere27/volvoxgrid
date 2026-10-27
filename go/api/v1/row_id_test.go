package v1

import (
	"bytes"
	"reflect"
	"testing"

	"google.golang.org/protobuf/proto"
)

func TestRowIDTrackingRequiresExplicitCreationOption(t *testing.T) {
	var legacy CreateRequest
	if legacy.GetRowIdsEnabled() {
		t.Fatal("omitting the creation option must leave row IDs disabled")
	}
	for _, enabled := range []bool{false, true} {
		original := &CreateRequest{RowIdsEnabled: enabled}
		encoded, err := proto.Marshal(original)
		if err != nil {
			t.Fatal(err)
		}
		if enabled && !bytes.Equal(encoded, []byte{40, 1}) {
			t.Fatalf("creation flag must use field 5: %x", encoded)
		}
		if !enabled && len(encoded) != 0 {
			t.Fatalf("default false must preserve the legacy empty request: %x", encoded)
		}
		var decoded CreateRequest
		if err := proto.Unmarshal(encoded, &decoded); err != nil {
			t.Fatal(err)
		}
		if decoded.GetRowIdsEnabled() != enabled {
			t.Fatalf("creation flag changed during serialization: %v", decoded.GetRowIdsEnabled())
		}
	}
}

func TestRowIDCodecPreservesInt64Precision(t *testing.T) {
	const maximum int64 = 1<<63 - 1
	ids := []int64{1, 1<<53 + 1, maximum}
	for _, id := range ids {
		original := &RowIdentity{Index: 7, RowId: id}
		encoded, err := proto.Marshal(original)
		if err != nil {
			t.Fatal(err)
		}
		var decoded RowIdentity
		if err := proto.Unmarshal(encoded, &decoded); err != nil {
			t.Fatal(err)
		}
		if decoded.GetRowId() != id {
			t.Fatalf("row ID lost precision: want %d, got %d", id, decoded.GetRowId())
		}
		if id == maximum && !bytes.Equal(encoded, []byte{8, 7, 16, 255, 255, 255, 255, 255, 255, 255, 255, 127}) {
			t.Fatalf("unexpected int64 wire encoding: %x", encoded)
		}
	}
	load := &LoadTableRequest{RowIds: ids}
	encoded, err := proto.Marshal(load)
	if err != nil {
		t.Fatal(err)
	}
	var decodedLoad LoadTableRequest
	if err := proto.Unmarshal(encoded, &decodedLoad); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(decodedLoad.GetRowIds(), ids) {
		t.Fatalf("bulk IDs changed: %v", decodedLoad.GetRowIds())
	}
	query := &GetRowsRequest{RowIds: ids}
	encoded, err = proto.Marshal(query)
	if err != nil {
		t.Fatal(err)
	}
	var decodedQuery GetRowsRequest
	if err := proto.Unmarshal(encoded, &decodedQuery); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(decodedQuery.GetRowIds(), ids) {
		t.Fatalf("lookup IDs changed: %v", decodedQuery.GetRowIds())
	}
}

func TestRowIDCodecEditEventsAndOptionalDefinition(t *testing.T) {
	const id int64 = 1<<63 - 1
	messages := []proto.Message{
		&RowDef{RowId: proto.Int64(id)},
		&EditorSession{RowId: id},
		&BeforeEditEvent{RowId: id},
		&StartEditEvent{RowId: id},
		&AfterEditEvent{RowId: id},
		&CellEditValidateEvent{RowId: id},
	}
	for _, original := range messages {
		encoded, err := proto.Marshal(original)
		if err != nil {
			t.Fatal(err)
		}
		decoded := original.ProtoReflect().New().Interface()
		if err := proto.Unmarshal(encoded, decoded); err != nil {
			t.Fatal(err)
		}
		if !proto.Equal(original, decoded) {
			t.Fatalf("%T changed during serialization: %v", original, decoded)
		}
	}
}
