package resources

import (
	"context"

	"git0.harness.io/l7B_kbSEQD2wjrM7PShm5w/PROD/Harness_Commons/harness-smp-installer/pkg/store"
	"github.com/rs/zerolog/log"
)

type ResourceCommand interface {
	Sync(ctx context.Context, configStore store.DataStore, outputStore store.DataStore) error
	Name() string
}

func CheckIsManaged(ctx context.Context, rc ResourceCommand, configStore store.DataStore) (bool, error) {
	isManaged, err := configStore.Get(ctx, rc.Name()+".manage")
	if err != nil {
		log.Err(err).Msgf("config store is wrongly configured")
		return false, err
	}
	isManagedB := isManaged.(bool)
	return isManagedB, nil
}
