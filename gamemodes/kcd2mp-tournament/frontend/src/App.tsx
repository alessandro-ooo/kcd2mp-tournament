import { Route, Switch, useLocation } from "wouter";
import { lazy } from "react";

const DuelSettingsPage = lazy(() => import("./wouter/duel-settings-page"));
const DuelInvitePage = lazy(() => import("./wouter/duel-invite-page"));
const DuelTimerPage = lazy(() => import("./wouter/duel-timer-page"));

type KcdMpRouter = { router: string };

const App = () => {
  const [, navigate] = useLocation();

  // KcdMp.onServer("panel.frontend", (value) => {
  //   const { router } = value as KcdMpRouter;
  //   if (router === "duelsettings") {
  //     navigate("/duel-settings-page");
  //   }

  //   if (router === "duelinvite") {
  //     navigate("/duel-invite-page");
  //   }
  // });

  return (
    <Switch>
      <Route path="/duel-settings-page">
        <DuelSettingsPage />
      </Route>
      <Route path="/duel-invite-page">
        <DuelInvitePage />
      </Route>
      <Route path="/duel-timer-page">
        <DuelTimerPage />
      </Route>
    </Switch>
  );
};

export default App;
