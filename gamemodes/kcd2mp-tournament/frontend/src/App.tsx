import { useEffect } from "react";
import { Route, Switch, useLocation } from "wouter";
import { lazy } from "react";

const DuelSettingsPage = lazy(() => import("./wouter/duel-settings-page"));
const DuelInvitePage = lazy(() => import("./wouter/duel-invite-page"));

const App = () => {
  const [, navigate] = useLocation();

  useEffect(
    () =>
      KcdMp.onServer("panel.duelsettings", (value) => {
        if (Array.isArray(value) && value[0] === "main") {
          navigate("/duel-settings-page");
        }
      }),
    [navigate],
  );

  return (
    <Switch>
      <Route path="/duel-settings-page" component={DuelSettingsPage} />
      <Route path="/duel-invite-page" component={DuelInvitePage} />
    </Switch>
  );
};

export default App;
