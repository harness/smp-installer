package resources

import (
	"context"

	"git0.harness.io/l7B_kbSEQD2wjrM7PShm5w/PROD/Harness_Commons/harness-smp-installer/pkg/client"
	"git0.harness.io/l7B_kbSEQD2wjrM7PShm5w/PROD/Harness_Commons/harness-smp-installer/pkg/store"
	"github.com/rs/zerolog/log"
)

type kubernetesCommand struct {
}

// Name implements ResourceCommand.
func (l *kubernetesCommand) Name() string {
	return "kubernetes"
}

// Sync implements ResourceCommand.
func (l *kubernetesCommand) Sync(ctx context.Context, configStore store.DataStore, outputStore store.DataStore) error {
	lbClient := client.NewKubernetesClient(l.Name(), configStore, outputStore)
	err := lbClient.PreExec(ctx)
	if err != nil {
		log.Error().Msgf("pre-exec step failed while syncing %s", l.Name())
		return err
	}
	err = lbClient.Exec(ctx)
	if err != nil {
		log.Error().Msgf("exec step failed while syncing %s", l.Name())
		return err
	}
	err = lbClient.PostExec(ctx)
	if err != nil {
		log.Error().Msgf("post-exec step failed while syncing %s", l.Name())
		return err
	}
	return nil
}

func NewKubernetesCommand() ResourceCommand {
	return &kubernetesCommand{}
}
